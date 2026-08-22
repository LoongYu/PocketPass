import Foundation
import Observation
import PocketPassCore
import SwiftUI

/// macOS 界面状态适配器。数据业务、去重、回收站、分类、标签和持久化
/// 均由 PocketPassCore.VaultStore 执行，macOS/iOS/iPadOS 不再维护三套逻辑。
@MainActor
@Observable
final class VaultStore {
    static let maximumAttachmentBytes = PocketPassCore.VaultStore.maximumAttachmentBytes
    var selectedSection: AppSection = .home
    var selectedCategoryID: UUID?
    var selectedItemID: UUID?
    var searchText = ""
    var showingAddItem = false
    var showingAddCategory = false
    var showingLockScreen = UserDefaults.standard.bool(forKey: "appLockEnabled")
    var lockAfterMinutes = UserDefaults.standard.object(forKey: "lockAfterMinutes") as? Int ?? 5 {
        didSet { UserDefaults.standard.set(lockAfterMinutes, forKey: "lockAfterMinutes") }
    }
    var appLockEnabled = UserDefaults.standard.bool(forKey: "appLockEnabled") {
        didSet {
            UserDefaults.standard.set(appLockEnabled, forKey: "appLockEnabled")
            if !appLockEnabled { showingLockScreen = false }
        }
    }
    var appearanceMode = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "") ?? .dark {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode") }
    }
    var appLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .simplifiedChinese {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage") }
    }
    var homeSortMode = HomeSortMode(rawValue: UserDefaults.standard.string(forKey: "homeSortMode") ?? "") ?? .modified {
        didSet { UserDefaults.standard.set(homeSortMode.rawValue, forKey: "homeSortMode") }
    }

    private let core: PocketPassCore.VaultStore
    private var contentRevision = 0
    var storageError: String?
    let appLockService = AppLockService()
    private var autoLockTask: Task<Void, Never>?

    init(repository: LocalVaultRepository = LocalVaultRepository()) {
        core = PocketPassCore.VaultStore(repository: repository.core)
        storageError = core.storageError
        selectedItemID = core.activeItems().first?.id
    }

    var categories: [VaultCategory] { _ = contentRevision; return core.categories }
    var items: [VaultItem] { _ = contentRevision; return core.items }
    var tags: [String] { _ = contentRevision; return core.tags }
    var customIcons: [CustomIcon] { _ = contentRevision; return core.customIcons }
    var allTags: [String] { core.allTags }
    var snapshot: VaultSnapshot { core.snapshot }

    var visibleItems: [VaultItem] {
        let filtered = items.filter { item in
            let sectionMatch = selectedSection == .trash ? item.deletedAt != nil : item.deletedAt == nil
            let categoryMatch = selectedCategoryID == nil || item.categoryID == selectedCategoryID
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatch = query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
                || item.website.localizedCaseInsensitiveContains(query)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                || item.accounts.contains { account in
                    account.username.localizedCaseInsensitiveContains(query)
                        || account.fields.contains { $0.name.localizedCaseInsensitiveContains(query) || $0.value.localizedCaseInsensitiveContains(query) }
                }
            return sectionMatch && categoryMatch && searchMatch
        }
        let categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        return filtered.sorted { lhs, rhs in
            switch homeSortMode {
            case .modified: return lhs.modifiedAt > rhs.modifiedAt
            case .name: return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .category:
                let left = categoryNames[lhs.categoryID] ?? "", right = categoryNames[rhs.categoryID] ?? ""
                return left == right ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : left.localizedStandardCompare(right) == .orderedAscending
            }
        }
    }

    var selectedItem: VaultItem? { items.first { $0.id == selectedItemID } }

    func addItem(name: String, accounts: [LoginAccount], tags: [String], website: String, categoryID: UUID, note: String, symbol: String = "key.fill", iconData: Data? = nil, attachments: [ImageAttachment] = []) {
        let item = core.addItem(name: name, accounts: accounts, tags: tags, website: website, categoryID: categoryID, note: note, symbol: symbol, iconData: iconData, attachments: attachments)
        selectedSection = .home; selectedCategoryID = nil; selectedItemID = item.id; touch()
    }
    func toggleFavorite(_ id: UUID) { core.toggleFavorite(id); touch() }
    func updateItem(_ item: VaultItem) { core.updateItem(item); touch() }
    func moveToTrash(_ id: UUID) { moveToTrash([id]) }
    func moveToTrash(_ ids: Set<UUID>) { core.moveToTrash(ids); if let selectedItemID, ids.contains(selectedItemID) { self.selectedItemID = nil }; touch() }
    func restore(_ id: UUID) { restore([id]) }
    func restore(_ ids: Set<UUID>) { core.restore(ids); touch() }
    func permanentlyDelete(_ id: UUID) { permanentlyDelete([id]) }
    func permanentlyDelete(_ ids: Set<UUID>) { core.permanentlyDelete(ids); if let selectedItemID, ids.contains(selectedItemID) { self.selectedItemID = nil }; touch() }

    func addCategory(name: String, icon: String, iconData: Data? = nil, colorHex: String) { core.addCategory(name: name, icon: icon, iconData: iconData, colorHex: colorHex); touch() }
    func updateCategory(_ category: VaultCategory) { core.updateCategory(category); touch() }
    func deleteCategory(_ id: UUID) { core.deleteCategory(id); touch() }
    func moveCategory(_ sourceID: UUID, to targetID: UUID) { core.moveCategory(sourceID, to: targetID); touch() }

    func addCustomIcons(_ icons: [CustomIcon]) -> Int { let count = core.addCustomIcons(icons); touch(); return count }
    func deleteCustomIcon(_ id: UUID) { core.deleteCustomIcon(id); touch() }
    func addTag(_ name: String) { core.addTag(name); touch() }
    func renameTag(_ old: String, to new: String) { core.renameTag(old, to: new); touch() }
    func deleteTag(_ tag: String) { core.deleteTag(tag); touch() }

    func merge(_ snapshot: VaultSnapshot) { _ = core.merge(snapshot); touch() }
    func merge(_ snapshot: VaultSnapshot, progress: (Int, Int) -> Void) async -> (inserted: Int, updated: Int, skipped: Int, accounts: Int) {
        let total = snapshot.items.count
        progress(0, total)
        await Task.yield()
        let result = core.merge(snapshot)
        progress(total, total)
        touch()
        let accounts = snapshot.items.reduce(0) { $0 + $1.accounts.count }
        return (result.inserted, result.updated, result.skipped, result.inserted + result.updated == 0 ? 0 : accounts)
    }
    func purgeExpiredTrash() { core.purgeExpiredTrash(); touch() }

    func appBecameInactive() {
        guard appLockEnabled else { return }
        autoLockTask?.cancel()
        if lockAfterMinutes == 0 { showingLockScreen = true; return }
        autoLockTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds((self?.lockAfterMinutes ?? 5) * 60))
            guard !Task.isCancelled else { return }
            self?.showingLockScreen = true
        }
    }
    func appBecameActive() { autoLockTask?.cancel() }

    private func touch() { contentRevision &+= 1; storageError = core.storageError }
}
