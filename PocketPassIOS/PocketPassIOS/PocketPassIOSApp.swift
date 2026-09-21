import SwiftUI

@main
struct PocketPassIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: VaultStore
    @StateObject private var settings = IOSAppSettings()

    init() {
#if targetEnvironment(simulator)
        if let encodedFixture = ProcessInfo.processInfo.environment["POCKETPASS_UI_TEST_BACKUP_BASE64"],
           let fixture = Data(base64Encoded: encodedFixture),
           let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            try? fixture.write(to: documents.appendingPathComponent("PocketPass-Import-Test.pocketpass"), options: .atomic)
            try? Data("{}".utf8).write(to: documents.appendingPathComponent("PocketPass-Import-Test.json"), options: .atomic)
            try? Data("unsupported".utf8).write(to: documents.appendingPathComponent("PocketPass-Unsupported.txt"), options: .atomic)
        }
#endif
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
