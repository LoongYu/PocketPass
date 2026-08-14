import Foundation
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case dark = "深色"
    case light = "亮色"
    case system = "跟随系统"
    var id: Self { self }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "简体中文"
    case english = "English"

    var id: Self { self }
    var locale: Locale { Locale(identifier: self == .english ? "en" : "zh-Hans") }
    func text(_ chinese: String, _ english: String) -> String { self == .english ? english : chinese }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .simplifiedChinese
    }
}

enum HomeSortMode: String, CaseIterable, Identifiable {
    case modified = "最近修改"
    case name = "名称"
    case category = "分类"
    var id: Self { self }
}

enum AppSection: String, CaseIterable, Identifiable {
    case home, categories, trash, settings
    var id: Self { self }
    var title: String {
        switch self {
        case .home: "首页"
        case .categories: "分类"
        case .trash: "回收站"
        case .settings: "设置"
        }
    }
    var icon: String {
        switch self {
        case .home: "house.fill"
        case .categories: "square.grid.2x2.fill"
        case .trash: "trash.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct VaultCategory: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var iconData: Data? = nil
    var colorHex: String
    var color: Color { Color(hex: colorHex) }
}

struct CustomField: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var value: String
    var isSecret: Bool
}

struct LoginAccount: Identifiable, Hashable, Codable {
    let id: UUID
    var username: String
    var password: String
    var fields: [CustomField]
}

struct ImageAttachment: Identifiable, Hashable, Codable {
    let id: UUID
    var filename: String
    var data: Data
}

struct CustomIcon: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var data: Data
    var addedAt: Date
}

struct VaultItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var website: String
    var categoryID: UUID
    var tags: [String]
    var note: String
    var symbol: String
    var iconData: Data? = nil
    var attachments: [ImageAttachment]? = nil
    var accounts: [LoginAccount]
    var isFavorite: Bool
    var modifiedAt: Date
    var deletedAt: Date?
}

extension VaultCategory {
    static let samples: [VaultCategory] = [
        .init(id: UUID(), name: "社交", icon: "bubble.left.and.bubble.right.fill", colorHex: "E45D9B"),
        .init(id: UUID(), name: "游戏", icon: "gamecontroller.fill", colorHex: "8B6FD6"),
        .init(id: UUID(), name: "银行", icon: "building.columns.fill", colorHex: "5792E8"),
        .init(id: UUID(), name: "工作", icon: "briefcase.fill", colorHex: "4DBB8A"),
        .init(id: UUID(), name: "购物", icon: "cart.fill", colorHex: "D69C4C"),
        .init(id: UUID(), name: "其他", icon: "folder.fill", colorHex: "9A9185")
    ]
}

struct VaultSnapshot: Codable {
    var formatVersion = 3
    var categories: [VaultCategory]
    var items: [VaultItem]
    var tags: [String]? = nil
    var customIcons: [CustomIcon]? = nil
}
