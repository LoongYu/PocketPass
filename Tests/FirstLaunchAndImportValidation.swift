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

        let movedCategoryID = store.categories.last!.id
        let firstCategoryID = store.categories.first!.id
        store.moveCategory(movedCategoryID, to: firstCategoryID)
        precondition(store.categories.first?.id == movedCategoryID, "分类拖拽排序未持久更新")

        let icon = CustomIcon(id: UUID(), name: "测试图标", data: Data([1, 2, 3]), addedAt: .now)
        precondition(store.addCustomIcons([icon]) == 1, "自定义图标应成功添加")
        precondition(store.addCustomIcons([icon]) == 0, "重复自定义图标不应再次添加")

        func importedSnapshot() -> VaultSnapshot {
            let category = VaultCategory(id: UUID(), name: "社交", icon: "folder.fill", colorHex: "888888")
            let item = VaultItem(
                id: UUID(), name: "重复校验", website: "https://example.com", categoryID: category.id,
                tags: ["测试"], note: "仅用于自动化测试", symbol: "key.fill",
                accounts: [LoginAccount(id: UUID(), username: "sample-user", password: "sample-pass", fields: [])],
                isFavorite: false, createdAt: .now, modifiedAt: .now, deletedAt: nil
            )
            return VaultSnapshot(categories: [category], items: [item])
        }

        store.merge(importedSnapshot())
        store.merge(importedSnapshot())
        precondition(store.items.count == 1, "重复导入相同内容时不应增加账户数量")
        precondition(store.categories.count == VaultCategory.samples.count, "同名分类不应重复创建")
        store.items[0].createdAt = .now.addingTimeInterval(-3_600)
        store.addItem(
            name: "刚添加的账户",
            accounts: [LoginAccount(id: UUID(), username: "new-user", password: "new-pass", fields: [])],
            tags: [], website: "", categoryID: store.categories[0].id, note: ""
        )
        store.homeSortMode = .added
        precondition(store.visibleItems.first?.name == "刚添加的账户", "按添加时间排序应优先显示新加入的账户")
        let reloaded = VaultStore(repository: LocalVaultRepository(directory: directory))
        precondition(reloaded.customIcons.count == 1, "自定义图标库应写入加密密码库")
        precondition(reloaded.categories.first?.id == movedCategoryID, "分类顺序应在重启后保持")
        print("first-launch-and-import-validation-ok")
    }
}
