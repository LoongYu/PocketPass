import CryptoKit
import Foundation

enum VaultStorageError: LocalizedError {
    case malformedCiphertext
    case malformedLocalKey

    var errorDescription: String? {
        switch self {
        case .malformedCiphertext: "本地密码库文件已损坏或无法解密"
        case .malformedLocalKey: "本地加密密钥已损坏"
        }
    }
}

final class LocalVaultRepository {
    private let fileURL: URL
    private let keyURL: URL
    private let legacyBackupURL: URL

    init(directory customDirectory: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = customDirectory ?? base.appendingPathComponent("口袋密码", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("vault.pocketdata")
        keyURL = directory.appendingPathComponent("vault-local.key")
        legacyBackupURL = directory.appendingPathComponent("vault-legacy-backup.pocketdata")
    }

    func load() throws -> VaultSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let hadLocalKey = FileManager.default.fileExists(atPath: keyURL.path)
        let key = try symmetricKey()
        if !hadLocalKey {
            if !FileManager.default.fileExists(atPath: legacyBackupURL.path) {
                try? FileManager.default.copyItem(at: fileURL, to: legacyBackupURL)
            }
            return nil
        }
        let encrypted = try Data(contentsOf: fileURL)
        guard let box = try? AES.GCM.SealedBox(combined: encrypted) else {
            throw VaultStorageError.malformedCiphertext
        }
        let plaintext = try AES.GCM.open(box, using: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VaultSnapshot.self, from: plaintext)
    }

    func save(_ snapshot: VaultSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let plaintext = try encoder.encode(snapshot)
        let sealed = try AES.GCM.seal(plaintext, using: symmetricKey())
        guard let combined = sealed.combined else { throw VaultStorageError.malformedCiphertext }
        try combined.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    private func symmetricKey() throws -> SymmetricKey {
        if FileManager.default.fileExists(atPath: keyURL.path) {
            let data = try Data(contentsOf: keyURL)
            guard data.count == 32 else { throw VaultStorageError.malformedLocalKey }
            return SymmetricKey(data: data)
        }

        let data = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
        try data.write(to: keyURL, options: [.atomic, .completeFileProtection])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        return SymmetricKey(data: data)
    }
}
