import Foundation

enum IOSAppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    var id: Self { self }
    var locale: Locale { Locale(identifier: rawValue) }
    func text(_ chinese: String, _ english: String) -> String {
        self == .english ? english : chinese
    }
}

enum IOSHomeSort: String, CaseIterable, Identifiable {
    case recentlyModified = "最近修改"
    case name = "名称"
    case category = "分类"
    var id: Self { self }
}

@MainActor
final class IOSAppSettings: ObservableObject {
    @Published var appearance: IOSAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "iosAppearance") }
    }
    @Published var appLockEnabled: Bool {
        didSet {
            UserDefaults.standard.set(appLockEnabled, forKey: "iosAppLockEnabled")
            if appLockEnabled { isLocked = true } else { isLocked = false }
        }
    }
    @Published var lockAfterSeconds: Int {
        didSet { UserDefaults.standard.set(lockAfterSeconds, forKey: "iosLockAfterSeconds") }
    }
    @Published var language: IOSAppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "iosLanguage") }
    }
    @Published var homeSort: IOSHomeSort {
        didSet { UserDefaults.standard.set(homeSort.rawValue, forKey: "iosHomeSort") }
    }
    @Published private(set) var isLocked: Bool
    private var autoLockTask: Task<Void, Never>?

    init() {
        appearance = IOSAppearance(rawValue: UserDefaults.standard.string(forKey: "iosAppearance") ?? "") ?? .dark
        appLockEnabled = UserDefaults.standard.bool(forKey: "iosAppLockEnabled")
        lockAfterSeconds = UserDefaults.standard.object(forKey: "iosLockAfterSeconds") as? Int ?? 300
        language = IOSAppLanguage(rawValue: UserDefaults.standard.string(forKey: "iosLanguage") ?? "") ?? .simplifiedChinese
        homeSort = IOSHomeSort(rawValue: UserDefaults.standard.string(forKey: "iosHomeSort") ?? "") ?? .recentlyModified
        isLocked = UserDefaults.standard.bool(forKey: "iosAppLockEnabled")
    }

    func appBecameInactive() {
        guard appLockEnabled else { return }
        autoLockTask?.cancel()
        if lockAfterSeconds == 0 { isLocked = true; return }
        autoLockTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(self?.lockAfterSeconds ?? 300))
            guard !Task.isCancelled else { return }
            self?.isLocked = true
        }
    }

    func appBecameActive() { autoLockTask?.cancel() }
    func unlockSucceeded() { isLocked = false }
    func lockNow() { if appLockEnabled { isLocked = true } }
}
