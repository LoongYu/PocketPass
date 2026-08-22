import Foundation

public struct VaultCategory: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var iconData: Data?
    public var colorHex: String

    public init(id: UUID = UUID(), name: String, icon: String, iconData: Data? = nil, colorHex: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.iconData = iconData
        self.colorHex = colorHex
    }
}

public struct CustomField: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var value: String
    public var isSecret: Bool

    public init(id: UUID = UUID(), name: String, value: String, isSecret: Bool = false) {
        self.id = id
        self.name = name
        self.value = value
        self.isSecret = isSecret
    }
}

public struct LoginAccount: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var username: String
    public var password: String
    public var fields: [CustomField]

    public init(id: UUID = UUID(), username: String, password: String, fields: [CustomField] = []) {
        self.id = id
        self.username = username
        self.password = password
        self.fields = fields
    }
}

public struct ImageAttachment: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var filename: String
    public var data: Data

    public init(id: UUID = UUID(), filename: String, data: Data) {
        self.id = id
        self.filename = filename
        self.data = data
    }
}

public struct CustomIcon: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var data: Data
    public var addedAt: Date

    public init(id: UUID = UUID(), name: String, data: Data, addedAt: Date = .now) {
        self.id = id
        self.name = name
        self.data = data
        self.addedAt = addedAt
    }
}

public struct VaultItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var website: String
    public var categoryID: UUID
    public var tags: [String]
    public var note: String
    public var symbol: String
    public var iconData: Data?
    public var attachments: [ImageAttachment]?
    public var accounts: [LoginAccount]
    public var isFavorite: Bool
    public var modifiedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        website: String = "",
        categoryID: UUID,
        tags: [String] = [],
        note: String = "",
        symbol: String = "key.fill",
        iconData: Data? = nil,
        attachments: [ImageAttachment]? = [],
        accounts: [LoginAccount],
        isFavorite: Bool = false,
        modifiedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.website = website
        self.categoryID = categoryID
        self.tags = tags
        self.note = note
        self.symbol = symbol
        self.iconData = iconData
        self.attachments = attachments
        self.accounts = accounts
        self.isFavorite = isFavorite
        self.modifiedAt = modifiedAt
        self.deletedAt = deletedAt
    }
}

public struct VaultSnapshot: Codable, Sendable {
    public var formatVersion: Int
    public var categories: [VaultCategory]
    public var items: [VaultItem]
    public var tags: [String]?
    public var customIcons: [CustomIcon]?

    public init(
        formatVersion: Int = 3,
        categories: [VaultCategory],
        items: [VaultItem],
        tags: [String]? = nil,
        customIcons: [CustomIcon]? = nil
    ) {
        self.formatVersion = formatVersion
        self.categories = categories
        self.items = items
        self.tags = tags
        self.customIcons = customIcons
    }
}

public extension VaultCategory {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "其他"
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "folder.fill"
        iconData = try container.decodeIfPresent(Data.self, forKey: .iconData)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "888888"
    }

    private enum CodingKeys: String, CodingKey { case id, name, icon, iconData, colorHex }
}

public extension CustomField {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "字段"
        value = try container.decodeIfPresent(String.self, forKey: .value) ?? ""
        isSecret = try container.decodeIfPresent(Bool.self, forKey: .isSecret) ?? false
    }

    private enum CodingKeys: String, CodingKey { case id, name, value, isSecret }
}

public extension LoginAccount {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        fields = try container.decodeIfPresent([CustomField].self, forKey: .fields) ?? []
    }

    private enum CodingKeys: String, CodingKey { case id, username, password, fields }
}

public extension VaultItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未命名账户"
        website = try container.decodeIfPresent(String.self, forKey: .website) ?? ""
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID) ?? UUID()
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? "key.fill"
        iconData = try container.decodeIfPresent(Data.self, forKey: .iconData)
        attachments = try container.decodeIfPresent([ImageAttachment].self, forKey: .attachments) ?? []
        accounts = try container.decodeIfPresent([LoginAccount].self, forKey: .accounts) ?? []
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, website, categoryID, tags, note, symbol, iconData, attachments, accounts
        case isFavorite, modifiedAt, deletedAt
    }
}

public extension VaultSnapshot {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        categories = try container.decodeIfPresent([VaultCategory].self, forKey: .categories) ?? []
        items = try container.decodeIfPresent([VaultItem].self, forKey: .items) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        customIcons = try container.decodeIfPresent([CustomIcon].self, forKey: .customIcons)
    }

    private enum CodingKeys: String, CodingKey { case formatVersion, categories, items, tags, customIcons }
}

public extension VaultCategory {
    static let defaultCategories: [VaultCategory] = [
        .init(name: "社交", icon: "bubble.left.and.bubble.right.fill", colorHex: "E45D9B"),
        .init(name: "游戏", icon: "gamecontroller.fill", colorHex: "8B6FD6"),
        .init(name: "银行", icon: "building.columns.fill", colorHex: "5792E8"),
        .init(name: "工作", icon: "briefcase.fill", colorHex: "4DBB8A"),
        .init(name: "购物", icon: "cart.fill", colorHex: "D69C4C"),
        .init(name: "其他", icon: "folder.fill", colorHex: "9A9185")
    ]
}
