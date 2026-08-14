import Foundation

@main
@MainActor
struct FirstLaunchAndImportValidation {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PocketPass-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        precondition(store.items.isEmpty, "首次启动不应包含测试账户")
        precondition(store.categories.count == VaultCategory.samples.count, "首次启动应保留默认分类")

        func importedSnapshot() -> VaultSnapshot {
            let category = VaultCategory(id: UUID(), name: "社交", icon: "folder.fill", colorHex: "888888")
            let item = VaultItem(
                id: UUID(), name: "重复校验", website: "https://example.com", categoryID: category.id,
                tags: ["测试"], note: "仅用于自动化测试", symbol: "key.fill",
                accounts: [LoginAccount(id: UUID(), username: "sample-user", password: "sample-pass", fields: [])],
                isFavorite: false, modifiedAt: .now, deletedAt: nil
            )
            return VaultSnapshot(categories: [category], items: [item])
        }

        store.merge(importedSnapshot())
        store.merge(importedSnapshot())
        precondition(store.items.count == 1, "重复导入相同内容时不应增加账户数量")
        precondition(store.categories.count == VaultCategory.samples.count, "同名分类不应重复创建")
        print("first-launch-and-import-validation-ok")
    }
}
