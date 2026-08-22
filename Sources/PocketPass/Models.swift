import Foundation
import PocketPassCore
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case dark = "深色"
    case light = "亮色"
    case system = "跟随系统"
    var id: Self { self }
    var colorScheme: ColorScheme? { switch self { case .dark: .dark; case .light: .light; case .system: nil } }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "简体中文"
    case english = "English"
    var id: Self { self }
    var locale: Locale { Locale(identifier: self == .english ? "en" : "zh-Hans") }
    func text(_ chinese: String, _ english: String) -> String { self == .english ? english : chinese }
    static var current: AppLanguage { AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .simplifiedChinese }
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
    var title: String { switch self { case .home: "首页"; case .categories: "分类"; case .trash: "回收站"; case .settings: "设置" } }
    var icon: String { switch self { case .home: "house.fill"; case .categories: "square.grid.2x2.fill"; case .trash: "trash.fill"; case .settings: "gearshape.fill" } }
}

typealias VaultCategory = PocketPassCore.VaultCategory
typealias CustomField = PocketPassCore.CustomField
typealias LoginAccount = PocketPassCore.LoginAccount
typealias ImageAttachment = PocketPassCore.ImageAttachment
typealias CustomIcon = PocketPassCore.CustomIcon
typealias VaultItem = PocketPassCore.VaultItem
typealias VaultSnapshot = PocketPassCore.VaultSnapshot

extension VaultCategory {
    static var samples: [VaultCategory] { defaultCategories }
    var color: Color { Color(hex: colorHex) }
}
