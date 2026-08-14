import Foundation

@main
struct SmokeTests {
    static func main() throws {
        let category = VaultCategory(id: UUID(), name: "测试", icon: "key.fill", colorHex: "F59E0B")
        let item = VaultItem(id: UUID(), name: "示例账户", website: "https://example.com", categoryID: category.id,
                             tags: ["测试"], note: "备注", symbol: "key.fill",
                             attachments: [.init(id: UUID(), filename: "pixel.png", data: Data([1, 2, 3]))],
                             accounts: [.init(id: UUID(), username: "tester", password: "secret",
                                              fields: [.init(id: UUID(), name: "PIN", value: "1234", isSecret: true)])],
                             isFavorite: true, modifiedAt: .now, deletedAt: nil)
        let customIcon = CustomIcon(id: UUID(), name: "自定义", data: Data([4, 5, 6]), addedAt: .now)
        let snapshot = VaultSnapshot(categories: [category], items: [item], customIcons: [customIcon])

        let json = try DataTransferService.json(snapshot: snapshot)
        let decoded = try DataTransferService.snapshot(fromJSON: json)
        precondition(decoded.items.first?.accounts.first?.fields.first?.value == "1234")
        precondition(decoded.customIcons?.first?.name == "自定义")

        let backup = try DataTransferService.encryptedBackup(snapshot: snapshot, password: "backup-pass")
        precondition(!String(decoding: backup, as: UTF8.self).contains("secret"))
        let restored = try DataTransferService.decryptBackup(backup, password: "backup-pass")
        precondition(restored.items.first?.attachments?.first?.filename == "pixel.png")

        let csv = DataTransferService.csv(snapshot: snapshot)
        let imported = try DataTransferService.snapshot(fromCSV: csv, baseCategories: [category])
        precondition(imported.items.first?.accounts.first?.username == "tester")
        print("smoke-tests-ok")
    }
}
