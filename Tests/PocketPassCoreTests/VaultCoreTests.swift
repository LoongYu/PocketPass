import Foundation
import Testing
@testable import PocketPassCore

@Suite("PocketPass shared core")
struct VaultCoreTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PocketPassCoreTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test @MainActor
    func encryptedPersistenceAndReload() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalVaultRepository(directory: directory)
        let store = VaultStore(repository: repository)
        let categoryID = try #require(store.categories.first?.id)
        store.addItem(
            name: "测试账户",
            accounts: [.init(username: "secret-user", password: "secret-password")],
            tags: ["常用"], website: "https://example.com", categoryID: categoryID, note: "encrypted"
        )

        let encrypted = try Data(contentsOf: directory.appendingPathComponent("vault.pocketdata"))
        #expect(!String(decoding: encrypted, as: UTF8.self).contains("secret-password"))
        #expect(try Data(contentsOf: directory.appendingPathComponent("vault-local.key")).count == 32)

        let reloaded = VaultStore(repository: LocalVaultRepository(directory: directory))
        #expect(reloaded.activeItems().count == 1)
        #expect(reloaded.activeItems().first?.accounts.first?.username == "secret-user")
    }

    @Test @MainActor
    func trashRestoreAndPermanentDelete() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        let item = store.addItem(
            name: "可删除账户", accounts: [.init(username: "u", password: "p")], tags: [], website: "",
            categoryID: try #require(store.categories.first?.id), note: ""
        )
        store.moveToTrash([item.id])
        #expect(store.activeItems().isEmpty)
        #expect(store.trashedItems.count == 1)
        store.restore([item.id])
        #expect(store.activeItems().count == 1)
        store.moveToTrash([item.id])
        store.permanentlyDelete([item.id])
        #expect(store.items.isEmpty)
    }

    @Test @MainActor
    func repeatedMergeIsIdempotent() throws {
        let sourceDirectory = try temporaryDirectory()
        let targetDirectory = try temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: targetDirectory)
        }
        let source = VaultStore(repository: LocalVaultRepository(directory: sourceDirectory))
        source.addItem(
            name: "导入项目", accounts: [.init(username: "same", password: "same")], tags: ["导入"], website: "",
            categoryID: try #require(source.categories.first?.id), note: ""
        )
        let target = VaultStore(repository: LocalVaultRepository(directory: targetDirectory))
        let first = target.merge(source.snapshot)
        let second = target.merge(source.snapshot)
        #expect(first.inserted == 1)
        #expect(second.skipped == 1)
        #expect(target.activeItems().count == 1)
    }

    @Test
    func passwordGeneratorHonorsConfiguration() {
        let password = PasswordGenerator.generate(length: 32, includeUppercase: true, includeNumbers: true, includeSymbols: true)
        #expect(password.count == 32)
        #expect(password.contains(where: { $0.isUppercase }))
        #expect(password.contains(where: { $0.isNumber }))
        #expect(password.contains(where: { "!@#$%^&*()-_=+[]{};:,.?".contains($0) }))
        #expect(Set((0..<128).map { _ in PasswordGenerator.generate(length: 20) }).count == 128)
    }

    @Test @MainActor
    func allTransferFormatsRoundTrip() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        store.addItem(
            name: "多格式账户",
            accounts: [.init(username: "roundtrip-user", password: "roundtrip-password", fields: [.init(name: "邮箱", value: "a@example.com")])],
            tags: ["测试", "导出"], website: "https://example.com", categoryID: try #require(store.categories.first?.id), note: "格式测试"
        )

        let json = try VaultDataTransfer.snapshot(fromJSON: VaultDataTransfer.json(snapshot: store.snapshot))
        let csv = try VaultDataTransfer.snapshot(fromCSV: VaultDataTransfer.csv(snapshot: store.snapshot), baseCategories: store.categories)
        let markdown = try VaultDataTransfer.snapshot(fromMarkdown: VaultDataTransfer.markdown(snapshot: store.snapshot), baseCategories: store.categories)
        let encrypted = try VaultDataTransfer.encryptedBackup(snapshot: store.snapshot, password: "backup-password")
        let backup = try VaultDataTransfer.decryptBackup(encrypted, password: "backup-password")

        for snapshot in [json, csv, markdown, backup] {
            #expect(snapshot.items.count == 1)
            #expect(snapshot.items.first?.accounts.first?.username == "roundtrip-user")
            #expect(snapshot.items.first?.accounts.first?.password == "roundtrip-password")
        }
        #expect(VaultDataTransfer.isEncryptedBackup(encrypted))
        #expect(!String(decoding: encrypted, as: UTF8.self).contains("roundtrip-password"))
    }

    @Test
    func completeFormatsPreserveAccountAndLibraryIcons() throws {
        let category = try #require(VaultCategory.defaultCategories.first)
        let accountIcon = Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02, 0x03])
        let categoryIcon = Data([0x89, 0x50, 0x4E, 0x47, 0x04, 0x05, 0x06])
        let libraryIcon = CustomIcon(name: "手工图标", data: Data([0x89, 0x50, 0x4E, 0x47, 0x07]))
        let customizedCategory = VaultCategory(
            id: category.id, name: category.name, icon: category.icon,
            iconData: categoryIcon, colorHex: category.colorHex
        )
        let source = VaultSnapshot(
            categories: [customizedCategory],
            items: [VaultItem(
                name: "图标迁移", categoryID: category.id,
                iconData: accountIcon,
                accounts: [LoginAccount(username: "icon-user", password: "icon-password")]
            )],
            customIcons: [libraryIcon]
        )

        let json = try VaultDataTransfer.snapshot(fromJSON: VaultDataTransfer.json(snapshot: source))
        let encrypted = try VaultDataTransfer.encryptedBackup(snapshot: source, password: "backup-password")
        let backup = try VaultDataTransfer.decryptBackup(encrypted, password: "backup-password")

        for restored in [json, backup] {
            #expect(restored.items.first?.iconData == accountIcon)
            #expect(restored.categories.first?.iconData == categoryIcon)
            #expect(restored.customIcons?.first?.data == libraryIcon.data)
        }
    }

    @Test
    func legacyMarkdownImportsMultipleLogins() throws {
        let markdown = """
        # 账户资料

        ### 微信小号
        分类：社交
        用户名：wechat-one
        密码：sample-one

        用户名：wechat-two
        密码：sample-two

        ### 谷歌账号
        分类：工作
        邮箱：google@example.com
        密码：sample-three
        密码提示：favorite color
        """
        let snapshot = try VaultDataTransfer.snapshot(fromMarkdown: Data(markdown.utf8), baseCategories: VaultCategory.defaultCategories)
        #expect(snapshot.items.count == 2)
        #expect(snapshot.items.first(where: { $0.name == "微信小号" })?.accounts.count == 2)
        #expect(snapshot.items.first(where: { $0.name == "谷歌账号" })?.accounts.first?.username == "google@example.com")
        #expect(snapshot.items.first(where: { $0.name == "谷歌账号" })?.accounts.first?.fields.first?.name == "密码提示")
    }

    @Test
    func markdownPreservesSecretDuplicateAndCredentialLikeCustomFields() throws {
        let category = try #require(VaultCategory.defaultCategories.first)
        let fields = [
            CustomField(name: "邮箱", value: "recovery@example.com"),
            CustomField(name: "密码提示", value: "not-the-password"),
            CustomField(name: "备用码", value: "first", isSecret: true),
            CustomField(name: "备用码", value: "second", isSecret: true)
        ]
        let source = VaultSnapshot(
            categories: [category],
            items: [VaultItem(
                name: "保真测试", categoryID: category.id,
                accounts: [LoginAccount(username: "primary", password: "secret", fields: fields)]
            )]
        )

        let decoded = try VaultDataTransfer.snapshot(
            fromMarkdown: VaultDataTransfer.markdown(snapshot: source), baseCategories: [category]
        )
        let account = try #require(decoded.items.first?.accounts.first)

        #expect(account.username == "primary")
        #expect(account.password == "secret")
        #expect(account.fields.map { [$0.name, $0.value, String($0.isSecret)] }
            == fields.map { [$0.name, $0.value, String($0.isSecret)] })
    }

    @Test @MainActor
    func missingKeyNeverOverwritesEncryptedVault() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        store.addItem(
            name: "不可覆盖", accounts: [.init(username: "owner", password: "critical-secret")], tags: [], website: "",
            categoryID: try #require(store.categories.first?.id), note: ""
        )
        let vaultURL = directory.appendingPathComponent("vault.pocketdata")
        let keyURL = directory.appendingPathComponent("vault-local.key")
        let encryptedBefore = try Data(contentsOf: vaultURL)
        try FileManager.default.removeItem(at: keyURL)

        let protectedStore = VaultStore(repository: LocalVaultRepository(directory: directory))

        #expect(protectedStore.storageError != nil)
        protectedStore.addItem(
            name: "不应写入", accounts: [.init(username: "new", password: "new")], tags: [], website: "",
            categoryID: try #require(protectedStore.categories.first?.id), note: ""
        )
        #expect(try Data(contentsOf: vaultURL) == encryptedBefore)
        #expect(!FileManager.default.fileExists(atPath: keyURL.path))
        #expect(protectedStore.activeItems().isEmpty)
    }

    @Test @MainActor
    func expiredTrashIsPurgedAndPersisted() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalVaultRepository(directory: directory)
        let store = VaultStore(repository: repository)
        var item = store.addItem(
            name: "过期项目", accounts: [.init(username: "u", password: "p")], tags: [], website: "",
            categoryID: try #require(store.categories.first?.id), note: ""
        )
        let referenceDate = Date(timeIntervalSince1970: 2_000_000_000)
        item.deletedAt = referenceDate.addingTimeInterval(-31 * 24 * 60 * 60)
        store.updateItem(item)
        store.purgeExpiredTrash(referenceDate: referenceDate)

        #expect(store.items.isEmpty)
        #expect(VaultStore(repository: LocalVaultRepository(directory: directory)).items.isEmpty)
    }

    @Test @MainActor
    func mergeRepairsOrphanCategoryAndLimitsAttachments() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        let smallAttachments = (0..<7).map { ImageAttachment(filename: "\($0).png", data: Data(repeating: UInt8($0), count: 32)) }
        let oversized = ImageAttachment(filename: "large.png", data: Data(repeating: 1, count: VaultStore.maximumAttachmentBytes + 1))
        let importedItem = VaultItem(
            name: "孤立分类", categoryID: UUID(), attachments: smallAttachments + [oversized],
            accounts: [.init(username: "u", password: "p")]
        )

        let result = store.merge(VaultSnapshot(categories: [], items: [importedItem]))
        let merged = try #require(store.activeItems().first)

        #expect(result.inserted == 1)
        #expect(store.categories.contains(where: { $0.id == merged.categoryID }))
        #expect(merged.attachments?.count == 5)
        #expect(merged.attachments?.allSatisfy { $0.data.count <= VaultStore.maximumAttachmentBytes } == true)
    }

    @Test @MainActor
    func deletingCategoryReassignsAllItems() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        let category = store.addCategory(name: "临时", icon: "folder.fill", colorHex: "FFCC00")
        store.addItem(
            name: "重分配", accounts: [.init(username: "u", password: "p")], tags: [], website: "",
            categoryID: category.id, note: ""
        )

        store.deleteCategory(category.id)

        #expect(!store.categories.contains(where: { $0.id == category.id }))
        #expect(store.items.allSatisfy { item in store.categories.contains(where: { $0.id == item.categoryID }) })
    }

    @Test @MainActor
    func searchCoversTagsAndNestedCustomFields() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        store.addItem(
            name: "内部系统",
            accounts: [.init(username: "employee", password: "p", fields: [.init(name: "恢复邮箱", value: "recover@example.com")])],
            tags: ["研发"], website: "", categoryID: try #require(store.categories.first?.id), note: ""
        )

        #expect(store.activeItems(searchText: "研发").count == 1)
        #expect(store.activeItems(searchText: "恢复邮箱").count == 1)
        #expect(store.activeItems(searchText: "recover@example.com").count == 1)
        #expect(store.activeItems(searchText: "不存在").isEmpty)
    }

    @Test
    func legacyJSONWithoutNewFieldsStillImports() throws {
        let categoryID = UUID()
        let itemID = UUID()
        let legacy = """
        {
          "categories": [{"id":"\(categoryID.uuidString)","name":"旧分类","icon":"folder.fill","colorHex":"888888"}],
          "items": [{
            "id":"\(itemID.uuidString)","name":"旧账户","categoryID":"\(categoryID.uuidString)",
            "accounts":[{"username":"legacy-user","password":"legacy-password"}]
          }]
        }
        """

        let snapshot = try VaultDataTransfer.snapshot(fromJSON: Data(legacy.utf8))
        let item = try #require(snapshot.items.first)

        #expect(snapshot.formatVersion == 1)
        #expect(item.website.isEmpty)
        #expect(item.tags.isEmpty)
        #expect(item.accounts.first?.fields.isEmpty == true)
        #expect(item.isFavorite == false)
    }

    @Test
    func csvCustomFieldPreservesEqualsCharacters() throws {
        let category = try #require(VaultCategory.defaultCategories.first)
        let item = VaultItem(
            name: "CSV 等号", categoryID: category.id,
            accounts: [.init(username: "u", password: "p", fields: [.init(name: "令牌", value: "a=b=c", isSecret: true)])]
        )
        let snapshot = VaultSnapshot(categories: [category], items: [item])

        let decoded = try VaultDataTransfer.snapshot(fromCSV: VaultDataTransfer.csv(snapshot: snapshot), baseCategories: [category])
        let field = try #require(decoded.items.first?.accounts.first?.fields.first)

        #expect(field.value == "a=b=c")
        #expect(field.isSecret)
    }

    @Test @MainActor
    func sharedStorageLimitsApplyBeyondTheUserInterface() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        let attachments = (0..<8).map { ImageAttachment(filename: "\($0).png", data: Data(repeating: 1, count: 20)) }
        let oversizedIcon = Data(repeating: 2, count: VaultStore.maximumIconBytes + 1)

        let item = store.addItem(
            name: "受限资源", accounts: [.init(username: "u", password: "p")], tags: [], website: "",
            categoryID: UUID(), note: "", iconData: oversizedIcon, attachments: attachments
        )

        #expect(item.iconData == nil)
        #expect(item.attachments?.count == VaultStore.maximumAttachmentCount)
        #expect(store.categories.contains(where: { $0.id == item.categoryID }))
        #expect(store.addCustomIcons([CustomIcon(name: "过大", data: oversizedIcon)]) == 0)
    }

    @Test @MainActor
    func tagsAndCategoryOrderPersistAcrossReload() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        let firstID = try #require(store.categories.first?.id)
        let lastID = try #require(store.categories.last?.id)
        store.moveCategory(lastID, to: firstID)
        store.addTag("  常用  ")
        store.addTag("常用")
        store.renameTag("常用", to: "个人")

        let reloaded = VaultStore(repository: LocalVaultRepository(directory: directory))
        #expect(reloaded.categories.first?.id == lastID)
        #expect(reloaded.tags == ["个人"])
    }

    @Test @MainActor
    func customIconLibraryDeduplicatesAndPersists() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultStore(repository: LocalVaultRepository(directory: directory))
        let data = Data([0x01, 0x02, 0x03])

        #expect(store.addCustomIcons([CustomIcon(name: "一", data: data), CustomIcon(name: "重复", data: data)]) == 1)
        #expect(store.addCustomIcons([CustomIcon(name: "再次重复", data: data)]) == 0)
        #expect(VaultStore(repository: LocalVaultRepository(directory: directory)).customIcons.count == 1)
    }
}
