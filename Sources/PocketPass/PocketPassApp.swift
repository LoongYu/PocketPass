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
                .preferredColorScheme(store.appearanceMode.colorScheme)
                .onAppear {
                    AppMenuBranding.apply(language: store.appLanguage)
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
}
