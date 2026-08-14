import AppKit

@MainActor
enum AppMenuBranding {
    static func apply(language: AppLanguage) {
        let brandName = language == .english ? "PocketPass" : "口袋密码"

        // SwiftUI creates the native menu after the scene begins appearing.
        // Updating on the next run-loop turn also makes in-app language changes immediate.
        DispatchQueue.main.async {
            guard let applicationMenuItem = NSApplication.shared.mainMenu?.items.first else { return }
            applicationMenuItem.title = brandName
            updateApplicationMenu(applicationMenuItem.submenu, brandName: brandName, language: language)
        }
    }

    private static func updateApplicationMenu(
        _ menu: NSMenu?,
        brandName: String,
        language: AppLanguage
    ) {
        guard let menu else { return }

        for item in menu.items {
            switch item.action {
            case #selector(NSApplication.orderFrontStandardAboutPanel(_:)):
                item.title = language.text("关于 \(brandName)", "About \(brandName)")
            case #selector(NSApplication.hide(_:)):
                item.title = language.text("隐藏 \(brandName)", "Hide \(brandName)")
            case #selector(NSApplication.hideOtherApplications(_:)):
                item.title = language.text("隐藏其他应用", "Hide Others")
            case #selector(NSApplication.unhideAllApplications(_:)):
                item.title = language.text("全部显示", "Show All")
            case #selector(NSApplication.terminate(_:)):
                item.title = language.text("退出 \(brandName)", "Quit \(brandName)")
            default:
                break
            }
        }
    }
}
