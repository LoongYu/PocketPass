import AppKit
import SwiftUI

@main
struct PocketPassApp: App {
    @State private var store = VaultStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, store.appLanguage.locale)
                .frame(minWidth: 1080, minHeight: 680)
                .onAppear {
                    applyAppearance(store.appearanceMode)
                    AppMenuBranding.apply(language: store.appLanguage)
                }
                .onChange(of: store.appearanceMode) { _, appearance in
                    applyAppearance(appearance)
                }
                .onChange(of: store.appLanguage) { _, language in
                    AppMenuBranding.apply(language: language)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.appBecameActive() }
                    else { store.appBecameInactive() }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        NSApp.appearance = switch mode {
        case .dark: NSAppearance(named: .darkAqua)
        case .light: NSAppearance(named: .aqua)
        case .system: nil
        }
    }
}
