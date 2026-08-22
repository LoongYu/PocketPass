import Combine
import Foundation

@MainActor
public final class VaultStore: ObservableObject {
    public static let maximumAttachmentCount = 5
    public static let maximumAttachmentBytes = 2_000_000
    public static let maximumIconBytes = 2_000_000
    public static let maximumCustomIconCount = 100
    @Published public private(set) var categories: [VaultCategory]
    @Published public private(set) var items: [VaultItem]
    @Published public private(set) var tags: [String]
    @Published public private(set) var customIcons: [CustomIcon]
    @Published public private(set) var storageError: String?

    private let repository: LocalVaultRepository
    private var writeBlocked = false
    private var lastPersistedSnapshot: VaultSnapshot?

    public init(repository: LocalVaultRepository = LocalVaultRepository()) {
        self.repository = repository
        var shouldCreateInitialSnapshot = false
        do {
            if let snapshot = try repository.load() {
                categories = snapshot.categories.isEmpty ? VaultCategory.defaultCategories : snapshot.categories
                items = snapshot.items
                tags = Array(Set((snapshot.tags ?? []) + snapshot.items.flatMap(\.tags))).sorted()
                customIcons = snapshot.customIcons ?? []
            } else {
                categories = VaultCategory.defaultCategories
                items = []
                tags = []
                customIcons = []
                shouldCreateInitialSnapshot = true
            }
        } catch {
            categories = VaultCategory.defaultCategories
            items = []
            tags = []
            customIcons = []
            storageError = error.localizedDescription
            writeBlocked = true
        }
        lastPersistedSnapshot = snapshot
        purgeExpiredTrash()
        if shouldCreateInitialSnapshot { persist() }
    }

    public var snapshot: VaultSnapshot {
        VaultSnapshot(categories: categories, items: items, tags: tags, customIcons: customIcons)
    }

    public func activeItems(categoryID: UUID? = nil, searchText: String = "") -> [VaultItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            guard item.deletedAt == nil, categoryID == nil || item.categoryID == categoryID else { return false }
            return query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
                || item.website.localizedCaseInsensitiveContains(query)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                || item.accounts.contains { account in
                    account.username.localizedCaseInsensitiveContains(query)
                        || account.fields.contains { $0.name.localizedCaseInsensitiveContains(query) || $0.value.localizedCaseInsensitiveContains(query) }
                }
        }.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public var trashedItems: [VaultItem] {
        items.filter { $0.deletedAt != nil }.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    public var allTags: [String] { tags.sorted() }

    @discardableResult
    public func addItem(
        name: String, accounts: [LoginAccount], tags: [String], website: String,
        categoryID: UUID, note: String, symbol: String = "key.fill", iconData: Data? = nil,
        attachments: [ImageAttachment] = []
    ) -> VaultItem {
        let resolvedCategoryID = categories.contains(where: { $0.id == categoryID }) ? categoryID : (categories.first?.id ?? categoryID)
        let item = VaultItem(name: name, website: website, categoryID: resolvedCategoryID, tags: tags, note: note,
                             symbol: symbol, iconData: sanitizedIcon(iconData),
                             attachments: sanitizedAttachments(attachments), accounts: accounts)
        items.insert(item, at: 0)
        self.tags = normalizedTags(self.tags + tags)
        persist()
        return item
    }

    public func updateItem(_ item: VaultItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        if !categories.contains(where: { $0.id == updated.categoryID }), let fallback = categories.first {
            updated.categoryID = fallback.id
        }
        updated.iconData = sanitizedIcon(updated.iconData)
        updated.attachments = sanitizedAttachments(updated.attachments ?? [])
        updated.modifiedAt = .now
        items[index] = updated
        tags = normalizedTags(tags + updated.tags)
        persist()
    }

    public func toggleFavorite(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isFavorite.toggle()
        items[index].modifiedAt = .now
        persist()
    }

    public func moveToTrash(_ ids: Set<UUID>) {
        let date = Date.now
        for index in items.indices where ids.contains(items[index].id) && items[index].deletedAt == nil {
            items[index].deletedAt = date
        }
        persist()
    }

    public func restore(_ ids: Set<UUID>) {
        for index in items.indices where ids.contains(items[index].id) {
            items[index].deletedAt = nil
            items[index].modifiedAt = .now
        }
        persist()
    }

    public func permanentlyDelete(_ ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
        persist()
    }

    @discardableResult
    public func addCategory(name: String, icon: String, iconData: Data? = nil, colorHex: String) -> VaultCategory {
        let category = VaultCategory(name: name, icon: icon, iconData: sanitizedIcon(iconData), colorHex: colorHex)
        categories.append(category)
        persist()
        return category
    }

    public func updateCategory(_ category: VaultCategory) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        var updated = category
        updated.iconData = sanitizedIcon(updated.iconData)
        categories[index] = updated
        persist()
    }

    public func moveCategory(fromOffsets: IndexSet, toOffset: Int) {
        let moving = fromOffsets.compactMap { categories.indices.contains($0) ? categories[$0] : nil }
        guard !moving.isEmpty else { return }
        let adjustedDestination = toOffset - fromOffsets.filter { $0 < toOffset }.count
        for index in fromOffsets.sorted(by: >) where categories.indices.contains(index) {
            categories.remove(at: index)
        }
        categories.insert(contentsOf: moving, at: min(max(0, adjustedDestination), categories.count))
        persist()
    }

    public func moveCategory(_ sourceID: UUID, to targetID: UUID) {
        guard sourceID != targetID,
              let sourceIndex = categories.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = categories.firstIndex(where: { $0.id == targetID }) else { return }
        let category = categories.remove(at: sourceIndex)
        categories.insert(category, at: min(targetIndex, categories.count))
        persist()
    }

    public func deleteCategory(_ id: UUID) {
        guard categories.count > 1, let replacement = categories.first(where: { $0.id != id }) else { return }
        for index in items.indices where items[index].categoryID == id {
            items[index].categoryID = replacement.id
            items[index].modifiedAt = .now
        }
        categories.removeAll { $0.id == id }
        persist()
    }

    public func addTag(_ value: String) {
        tags = normalizedTags(tags + [value])
        persist()
    }

    public func renameTag(_ oldValue: String, to newValue: String) {
        let newValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newValue.isEmpty else { return }
        for index in items.indices {
            items[index].tags = normalizedTags(items[index].tags.map { $0 == oldValue ? newValue : $0 })
        }
        tags = normalizedTags(tags.map { $0 == oldValue ? newValue : $0 })
        persist()
    }

    public func deleteTag(_ value: String) {
        tags.removeAll { $0 == value }
        for index in items.indices { items[index].tags.removeAll { $0 == value } }
        persist()
    }

    public func addCustomIcons(_ icons: [CustomIcon]) -> Int {
        var added = 0
        for icon in icons where customIcons.count < Self.maximumCustomIconCount
            && icon.data.count <= Self.maximumIconBytes
            && !customIcons.contains(where: { $0.data == icon.data }) {
            customIcons.append(icon)
            added += 1
        }
        customIcons.sort { $0.addedAt > $1.addedAt }
        if added > 0 { persist() }
        return added
    }

    public func deleteCustomIcon(_ id: UUID) {
        customIcons.removeAll { $0.id == id }
        persist()
    }

    public func merge(_ imported: VaultSnapshot) -> (inserted: Int, updated: Int, skipped: Int) {
        var categoryMap: [UUID: UUID] = [:]
        for var category in imported.categories {
            category.iconData = sanitizedIcon(category.iconData)
            if let existing = categories.first(where: { $0.id == category.id || $0.name.caseInsensitiveCompare(category.name) == .orderedSame }) {
                categoryMap[category.id] = existing.id
            } else {
                categories.append(category)
                categoryMap[category.id] = category.id
            }
        }
        var result = (inserted: 0, updated: 0, skipped: 0)
        for var item in imported.items {
            if let mappedCategoryID = categoryMap[item.categoryID] {
                item.categoryID = mappedCategoryID
            } else if !categories.contains(where: { $0.id == item.categoryID }), let fallback = categories.first {
                item.categoryID = fallback.id
            }
            item.iconData = sanitizedIcon(item.iconData)
            item.attachments = sanitizedAttachments(item.attachments ?? [])
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                if item.modifiedAt > items[index].modifiedAt { items[index] = item; result.updated += 1 }
                else { result.skipped += 1 }
            } else if items.contains(where: { semanticSignature($0) == semanticSignature(item) }) {
                result.skipped += 1
            } else {
                items.append(item)
                result.inserted += 1
            }
        }
        tags = normalizedTags(tags + (imported.tags ?? []) + imported.items.flatMap(\.tags))
        _ = addCustomIcons(imported.customIcons ?? [])
        persist()
        return result
    }

    public func purgeExpiredTrash(referenceDate: Date = .now) {
        let cutoff = referenceDate.addingTimeInterval(-30 * 24 * 60 * 60)
        let previousCount = items.count
        items.removeAll { ($0.deletedAt ?? .distantFuture) < cutoff }
        if items.count != previousCount { persist() }
    }

    private func persist() {
        guard !writeBlocked else {
            restore(lastPersistedSnapshot)
            return
        }
        do {
            try repository.save(snapshot)
            lastPersistedSnapshot = snapshot
            storageError = nil
        } catch {
            restore(lastPersistedSnapshot)
            storageError = error.localizedDescription
        }
    }

    private func restore(_ saved: VaultSnapshot?) {
        guard let saved else { return }
        categories = saved.categories
        items = saved.items
        tags = saved.tags ?? []
        customIcons = saved.customIcons ?? []
    }

    private func normalizedTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
            guard !trimmed.isEmpty, seen.insert(key).inserted else { return nil }
            return trimmed
        }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func sanitizedIcon(_ data: Data?) -> Data? {
        guard let data, data.count <= Self.maximumIconBytes else { return nil }
        return data
    }

    private func sanitizedAttachments(_ attachments: [ImageAttachment]) -> [ImageAttachment] {
        Array(attachments
            .filter { $0.data.count <= Self.maximumAttachmentBytes }
            .prefix(Self.maximumAttachmentCount))
    }

    private func semanticSignature(_ item: VaultItem) -> String {
        func folded(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
        }
        let accounts = item.accounts.map { account in
            let fields = account.fields.map { "\(folded($0.name))|\($0.value)|\($0.isSecret)" }.sorted().joined(separator: "¶")
            return "\(account.username)|\(account.password)|\(fields)"
        }.sorted().joined(separator: "¤")
        return [folded(item.name), item.categoryID.uuidString, item.website, item.note, accounts].joined(separator: "※")
    }
}
