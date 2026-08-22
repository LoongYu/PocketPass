import CryptoKit
import Foundation

public enum VaultStorageError: LocalizedError, Sendable {
    case malformedCiphertext
    case malformedLocalKey
    case missingLocalKey

    public var errorDescription: String? {
        switch self {
        case .malformedCiphertext: "本地密码库文件已损坏或无法解密"
        case .malformedLocalKey: "本地加密密钥已损坏"
        case .missingLocalKey: "本地密码库的加密密钥缺失，已停止读取以保护原数据"
        }
    }
}

public final class LocalVaultRepository: @unchecked Sendable {
    private let fileURL: URL
    private let keyURL: URL
    private let fileManager: FileManager

    public init(directory customDirectory: URL? = nil, namespace: String = "PocketPass") {
        fileManager = .default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = customDirectory ?? base.appendingPathComponent(namespace, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("vault.pocketdata")
        keyURL = directory.appendingPathComponent("vault-local.key")
    }

    public func load() throws -> VaultSnapshot? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        guard fileManager.fileExists(atPath: keyURL.path) else { throw VaultStorageError.missingLocalKey }
        let encrypted = try Data(contentsOf: fileURL)
        let box = try AES.GCM.SealedBox(combined: encrypted)
        let plaintext = try AES.GCM.open(box, using: try symmetricKey())
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VaultSnapshot.self, from: plaintext)
    }

    public func save(_ snapshot: VaultSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let plaintext = try encoder.encode(snapshot)
        let sealed = try AES.GCM.seal(plaintext, using: try symmetricKey())
        guard let combined = sealed.combined else { throw VaultStorageError.malformedCiphertext }
        try combined.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    public func removeAllData() throws {
        if fileManager.fileExists(atPath: fileURL.path) { try fileManager.removeItem(at: fileURL) }
        if fileManager.fileExists(atPath: keyURL.path) { try fileManager.removeItem(at: keyURL) }
    }

    private func symmetricKey() throws -> SymmetricKey {
        if fileManager.fileExists(atPath: keyURL.path) {
            let data = try Data(contentsOf: keyURL)
            guard data.count == 32 else { throw VaultStorageError.malformedLocalKey }
            return SymmetricKey(data: data)
        }
        var generator = SystemRandomNumberGenerator()
        let data = Data((0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
        try data.write(to: keyURL, options: [.atomic, .completeFileProtection])
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        return SymmetricKey(data: data)
    }
}
