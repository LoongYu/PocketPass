import SwiftUI

@main
struct PocketPassIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: VaultStore
    @StateObject private var settings = IOSAppSettings()

    init() {
        let store = VaultStore(repository: LocalVaultRepository(namespace: "PocketPassIOS"))
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.isLocked {
                    IOSLockScreen()
                } else {
                    IOSRootView()
                }
            }
                .environmentObject(store)
                .environmentObject(settings)
                .environment(\.locale, settings.language.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: settings.appBecameActive()
                    case .inactive, .background: settings.appBecameInactive()
                    @unknown default: break
                    }
                }
        }
    }
}
