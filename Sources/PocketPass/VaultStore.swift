import Foundation
import SwiftUI

@MainActor
@Observable
final class VaultStore {
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
    var categories = VaultCategory.samples
    var tags: [String] = []
    var items: [VaultItem] = []
    var storageError: String?
    private let repository: LocalVaultRepository
    let appLockService = AppLockService()
    private var autoLockTask: Task<Void, Never>?

    init(repository: LocalVaultRepository = LocalVaultRepository()) {
        self.repository = repository
        do {
            if let snapshot = try repository.load() {
                categories = snapshot.categories
                items = snapshot.items
                tags = Array(Set((snapshot.tags ?? []) + snapshot.items.flatMap(\.tags))).sorted()
                purgeExpiredTrash()
                selectedItemID = items.first { $0.deletedAt == nil }?.id
                return
            }
        } catch {
            storageError = error.localizedDescription
            items = []
            return
        }
        items = []
        selectedItemID = nil
        tags = []
        persist()
    }

    var visibleItems: [VaultItem] {
        let filtered = items.filter { item in
            let sectionMatch: Bool = switch selectedSection {
            case .categories: item.deletedAt == nil
            case .trash: item.deletedAt != nil
            default: item.deletedAt == nil
            }
            let categoryMatch = selectedCategoryID == nil || item.categoryID == selectedCategoryID
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatch = query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
                || item.website.localizedCaseInsensitiveContains(query)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                || item.accounts.contains { account in
                    account.username.localizedCaseInsensitiveContains(query)
                        || account.fields.contains {
                            $0.name.localizedCaseInsensitiveContains(query)
                                || $0.value.localizedCaseInsensitiveContains(query)
                        }
                }
            return sectionMatch && categoryMatch && searchMatch
        }
        let categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        return filtered.sorted { lhs, rhs in
            switch homeSortMode {
            case .modified:
                return lhs.modifiedAt > rhs.modifiedAt
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .category:
                let left = categoryNames[lhs.categoryID] ?? ""
                let right = categoryNames[rhs.categoryID] ?? ""
                if left == right { return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending }
                return left.localizedStandardCompare(right) == .orderedAscending
            }
        }
    }

    var selectedItem: VaultItem? {
        items.first { $0.id == selectedItemID }
    }

    func addItem(name: String, accounts: [LoginAccount], tags: [String], website: String, categoryID: UUID, note: String, symbol: String = "key.fill", iconData: Data? = nil, attachments: [ImageAttachment] = []) {
        let item = VaultItem(id: UUID(), name: name, website: website, categoryID: categoryID,
                             tags: tags, note: note, symbol: symbol, iconData: iconData, attachments: attachments,
                             accounts: accounts,
                             isFavorite: false, modifiedAt: .now, deletedAt: nil)
        items.insert(item, at: 0)
        self.tags = Array(Set(self.tags + tags)).sorted()
        selectedSection = .home
        selectedCategoryID = nil
        selectedItemID = item.id
        persist()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isFavorite.toggle()
        items[index].modifiedAt = .now
        persist()
    }

    func updateItem(_ item: VaultItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.modifiedAt = .now
        items[index] = updated
        tags = Array(Set(tags + updated.tags)).sorted()
        persist()
    }

    func moveToTrash(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].deletedAt = .now
        selectedItemID = nil
        persist()
    }

    func moveToTrash(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let deletedAt = Date.now
        for index in items.indices where ids.contains(items[index].id) && items[index].deletedAt == nil {
            items[index].deletedAt = deletedAt
        }
        if let selectedItemID, ids.contains(selectedItemID) { self.selectedItemID = nil }
        persist()
    }

    func restore(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].deletedAt = nil
        items[index].modifiedAt = .now
        persist()
    }

    func restore(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let modifiedAt = Date.now
        for index in items.indices where ids.contains(items[index].id) && items[index].deletedAt != nil {
            items[index].deletedAt = nil
            items[index].modifiedAt = modifiedAt
        }
        if let selectedItemID, ids.contains(selectedItemID) { self.selectedItemID = nil }
        persist()
    }

    func addCategory(name: String, icon: String, iconData: Data? = nil, colorHex: String) {
        categories.append(.init(id: UUID(), name: name, icon: icon, iconData: iconData, colorHex: colorHex))
        persist()
    }

    func updateCategory(_ category: VaultCategory) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index] = category
        persist()
    }

    func deleteCategory(_ id: UUID) {
        guard categories.count > 1 else { return }
        let replacement: VaultCategory
        if let other = categories.first(where: { $0.id != id && $0.name == "其他" }) { replacement = other }
        else if let first = categories.first(where: { $0.id != id }) { replacement = first }
        else { return }
        for index in items.indices where items[index].categoryID == id {
            items[index].categoryID = replacement.id
            items[index].modifiedAt = .now
        }
        categories.removeAll { $0.id == id }
        persist()
    }

    var allTags: [String] { tags.sorted() }

    func addTag(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        tags.append(trimmed)
        tags.sort()
        persist()
    }

    func renameTag(_ old: String, to new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        for index in items.indices where items[index].tags.contains(old) {
            items[index].tags = Array(Set(items[index].tags.map { $0 == old ? trimmed : $0 })).sorted()
            items[index].modifiedAt = .now
        }
        tags = Array(Set(tags.map { $0 == old ? trimmed : $0 })).sorted()
        persist()
    }

    func deleteTag(_ tag: String) {
        for index in items.indices { items[index].tags.removeAll { $0 == tag } }
        tags.removeAll { $0 == tag }
        persist()
    }

    func permanentlyDelete(_ id: UUID) {
        items.removeAll { $0.id == id }
        if selectedItemID == id { selectedItemID = nil }
        persist()
    }

    func permanentlyDelete(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
        if let selectedItemID, ids.contains(selectedItemID) { self.selectedItemID = nil }
        persist()
    }

    var snapshot: VaultSnapshot { .init(categories: categories, items: items, tags: tags) }

    func merge(_ snapshot: VaultSnapshot) {
        let categoryMapping = mergeCategories(from: snapshot)
        for imported in snapshot.items {
            var remapped = imported
            remapped.categoryID = categoryMapping[imported.categoryID] ?? imported.categoryID
            _ = mergeItem(remapped)
        }
        finishMerge(snapshot)
    }

    func merge(_ snapshot: VaultSnapshot, progress: (Int, Int) -> Void) async -> (inserted: Int, updated: Int, skipped: Int, accounts: Int) {
        let categoryMapping = mergeCategories(from: snapshot)
        let total = snapshot.items.count
        var inserted = 0
        var updated = 0
        var skipped = 0
        var importedAccounts = 0
        progress(0, total)
        for (offset, imported) in snapshot.items.enumerated() {
            var remapped = imported
            remapped.categoryID = categoryMapping[imported.categoryID] ?? imported.categoryID
            switch mergeItem(remapped) {
            case .inserted:
                inserted += 1
                importedAccounts += remapped.accounts.count
            case .updated:
                updated += 1
                importedAccounts += remapped.accounts.count
            case .skipped:
                skipped += 1
            }
            progress(offset + 1, total)
            if offset.isMultiple(of: 4) {
                try? await Task.sleep(for: .milliseconds(12))
            } else {
                await Task.yield()
            }
        }
        finishMerge(snapshot)
        return (inserted, updated, skipped, importedAccounts)
    }

    private func mergeCategories(from snapshot: VaultSnapshot) -> [UUID: UUID] {
        var mapping: [UUID: UUID] = [:]
        for category in snapshot.categories {
            if let existing = categories.first(where: { $0.id == category.id }) {
                mapping[category.id] = existing.id
            } else if let existing = categories.first(where: {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(category.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            }) {
                mapping[category.id] = existing.id
            } else {
                categories.append(category)
                mapping[category.id] = category.id
            }
        }
        return mapping
    }

    private enum MergeItemResult { case inserted, updated, skipped }

    private func mergeItem(_ imported: VaultItem) -> MergeItemResult {
        if let index = items.firstIndex(where: { $0.id == imported.id }) {
            if imported.modifiedAt > items[index].modifiedAt {
                items[index] = imported
                return .updated
            }
            return .skipped
        } else if items.contains(where: { semanticSignature(of: $0) == semanticSignature(of: imported) }) {
            return .skipped
        } else {
            items.append(imported)
            return .inserted
        }
    }

    /// IDs generated while parsing Markdown and CSV are intentionally ignored here.
    /// This makes importing the same external file idempotent without merging two
    /// genuinely different account projects that merely share a display name.
    private func semanticSignature(of item: VaultItem) -> String {
        func folded(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
        }
        func exact(_ value: String) -> String { "\(value.utf8.count):\(value)" }
        func fieldSignature(_ field: CustomField) -> String {
            [folded(field.name), exact(field.value), field.isSecret ? "1" : "0"].joined(separator: "|")
        }
        func accountSignature(_ account: LoginAccount) -> String {
            let fields = account.fields.map(fieldSignature).sorted().joined(separator: "¶")
            return [exact(account.username), exact(account.password), fields].joined(separator: "§")
        }

        let accountSignatures = item.accounts.map(accountSignature).sorted().joined(separator: "¤")
        let tags = item.tags.map(folded).sorted().joined(separator: "|")
        let attachmentSignatures = (item.attachments ?? []).map {
            "\(folded($0.filename)):\($0.data.base64EncodedString())"
        }.sorted().joined(separator: "|")
        return [
            folded(item.name), item.categoryID.uuidString, exact(item.website), tags,
            exact(item.note), folded(item.symbol), item.iconData?.base64EncodedString() ?? "",
            attachmentSignatures, accountSignatures, item.deletedAt == nil ? "active" : "deleted"
        ].joined(separator: "※")
    }

    private func finishMerge(_ snapshot: VaultSnapshot) {
        tags = Array(Set(tags + (snapshot.tags ?? []) + snapshot.items.flatMap(\.tags))).sorted()
        persist()
    }

    func purgeExpiredTrash() {
        let cutoff = Date.now.addingTimeInterval(-30 * 24 * 60 * 60)
        items.removeAll { item in
            guard let deletedAt = item.deletedAt else { return false }
            return deletedAt < cutoff
        }
        persist()
    }

    private func persist() {
        do {
            try repository.save(.init(categories: categories, items: items, tags: tags))
            storageError = nil
        } catch {
            storageError = error.localizedDescription
        }
    }

    func appBecameInactive() {
        guard appLockEnabled else { return }
        autoLockTask?.cancel()
        let delay = lockAfterMinutes
        if delay == 0 {
            showingLockScreen = true
            return
        }
        autoLockTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay * 60))
            guard !Task.isCancelled else { return }
            self?.showingLockScreen = true
        }
    }

    func appBecameActive() {
        autoLockTask?.cancel()
    }

}
