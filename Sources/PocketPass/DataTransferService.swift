import Foundation
import PocketPassCore
import SwiftUI
import UniformTypeIdentifiers

struct TransferDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json, .commaSeparatedText, DataTransferService.markdownType, DataTransferService.backupType, DataTransferService.legacyBackupType]
    }
    var data = Data()
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// 文件格式标识保留在 UI 层，所有编解码和加密逻辑由 PocketPassCore 共享。
enum DataTransferService {
    static let backupType = UTType(exportedAs: "com.loongyu.pocketpass.backup", conformingTo: .data)
    static let legacyBackupType = UTType(importedAs: "com.loongyu.pockit.backup", conformingTo: .data)
    static let markdownType = UTType(filenameExtension: "md") ?? .plainText

    static func json(snapshot: VaultSnapshot) throws -> Data { try VaultDataTransfer.json(snapshot: snapshot) }
    static func snapshot(fromJSON data: Data) throws -> VaultSnapshot { try VaultDataTransfer.snapshot(fromJSON: data) }
    static func csv(snapshot: VaultSnapshot) -> Data { VaultDataTransfer.csv(snapshot: snapshot) }
    static func snapshot(fromCSV data: Data, baseCategories: [VaultCategory]) throws -> VaultSnapshot {
        try VaultDataTransfer.snapshot(fromCSV: data, baseCategories: baseCategories)
    }
    static func markdown(snapshot: VaultSnapshot) -> Data { VaultDataTransfer.markdown(snapshot: snapshot) }
    static func snapshot(fromMarkdown data: Data, baseCategories: [VaultCategory]) throws -> VaultSnapshot {
        try VaultDataTransfer.snapshot(fromMarkdown: data, baseCategories: baseCategories)
    }
    static func encryptedBackup(snapshot: VaultSnapshot, password: String) throws -> Data {
        try VaultDataTransfer.encryptedBackup(snapshot: snapshot, password: password)
    }
    static func decryptBackup(_ data: Data, password: String) throws -> VaultSnapshot {
        try VaultDataTransfer.decryptBackup(data, password: password)
    }
    static func isEncryptedBackup(_ data: Data) -> Bool { VaultDataTransfer.isEncryptedBackup(data) }
}
