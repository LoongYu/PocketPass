import Foundation

@main
@MainActor
struct CompletedFeaturesValidation {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PocketPass-completed-features-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        expect(store.items.isEmpty, "首次启动不包含账户")
        expect(store.categories.count == 6, "首次启动包含六个默认分类")

        store.addCategory(name: "测试分类", icon: "star.fill", colorHex: "123456")
        guard var category = store.categories.first(where: { $0.name == "测试分类" }) else {
            throw ValidationError("新增分类失败")
        }
        category.name = "已编辑分类"
        category.icon = "heart.fill"
        category.colorHex = "654321"
        store.updateCategory(category)
        expect(store.categories.contains(where: {
            $0.id == category.id && $0.name == "已编辑分类" && $0.icon == "heart.fill" && $0.colorHex == "654321"
        }), "分类编辑未保存")

        store.addTag("常用")
        store.addTag("工作")
        store.addTag("常用")
        expect(store.allTags == ["工作", "常用"], "标签新增或去重失败")

        let primaryAccount = LoginAccount(
            id: UUID(), username: "pocket-user", password: "unique-secret-value",
            fields: [
                .init(id: UUID(), name: "网址", value: "https://example.com", isSecret: false),
                .init(id: UUID(), name: "PIN", value: "2468", isSecret: true)
            ]
        )
        let secondaryAccount = LoginAccount(
            id: UUID(), username: "second-user", password: "second-secret", fields: []
        )
        store.addItem(
            name: "示例服务", accounts: [primaryAccount, secondaryAccount], tags: ["常用"], website: "",
            categoryID: category.id, note: "测试备注", symbol: "heart.fill", iconData: Data([9, 8, 7]),
            attachments: [.init(id: UUID(), filename: "sample.png", data: Data([1, 2, 3]))]
        )
        guard let itemID = store.selectedItemID else { throw ValidationError("新增账户失败") }
        expect(store.selectedItem?.accounts.count == 2, "多登录账号保存失败")
        expect(store.selectedItem?.accounts.first?.fields.count == 2, "自定义字段保存失败")
        expect(store.selectedItem?.attachments?.count == 1, "附件保存失败")

        store.searchText = "example.com"
        expect(store.visibleItems.map(\.id) == [itemID], "自定义字段内容搜索失败")
        store.searchText = "pocket-user"
        expect(store.visibleItems.map(\.id) == [itemID], "用户名搜索失败")
        store.searchText = "常用"
        expect(store.visibleItems.map(\.id) == [itemID], "标签搜索失败")
        store.searchText = ""

        store.renameTag("常用", to: "重要")
        expect(store.selectedItem?.tags == ["重要"], "标签重命名未同步到账户")
        store.deleteTag("重要")
        expect(store.selectedItem?.tags.isEmpty == true, "标签删除未同步到账户")

        if var renamedItem = store.items.first(where: { $0.id == itemID }) {
            renamedItem.name = "Z 服务"
            store.updateItem(renamedItem)
        }

        store.addItem(
            name: "A 服务", accounts: [.init(id: UUID(), username: "alpha", password: "alpha-secret", fields: [])],
            tags: [], website: "", categoryID: store.categories[0].id, note: ""
        )
        store.homeSortMode = .name
        expect(store.visibleItems.first?.name == "A 服务", "名称排序失败")
        store.homeSortMode = .category
        expect(store.visibleItems.count == 2, "分类排序丢失账户")

        store.deleteCategory(category.id)
        expect(!store.categories.contains(where: { $0.id == category.id }), "分类删除失败")
        expect(store.items.first(where: { $0.id == itemID })?.categoryID != category.id, "删除分类后账户未迁移")

        store.moveToTrash(itemID)
        expect(store.items.first(where: { $0.id == itemID })?.deletedAt != nil, "移入回收站失败")
        store.restore(itemID)
        expect(store.items.first(where: { $0.id == itemID })?.deletedAt == nil, "回收站恢复失败")
        store.moveToTrash(itemID)
        store.permanentlyDelete(itemID)
        expect(!store.items.contains(where: { $0.id == itemID }), "永久删除失败")

        let encryptedData = try Data(contentsOf: directory.appendingPathComponent("vault.pocketdata"))
        expect(!String(decoding: encryptedData, as: UTF8.self).contains("alpha-secret"), "本地密码库包含可见明文")
        expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("vault-local.key").path), "本地密钥未生成")

        let reloaded = VaultStore(repository: LocalVaultRepository(directory: directory))
        expect(reloaded.items.count == 1 && reloaded.items.first?.name == "A 服务", "加密密码库持久化或重新加载失败")

        print("completed-features-validation-ok: accounts, categories, tags, search, sorting, trash, encryption, persistence")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    private struct ValidationError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
