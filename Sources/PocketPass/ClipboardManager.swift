import AppKit

enum ClipboardManager {
    static func copy(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        let changeCount = pasteboard.changeCount
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            guard NSPasteboard.general.changeCount == changeCount else { return }
            NSPasteboard.general.clearContents()
        }
    }
}
