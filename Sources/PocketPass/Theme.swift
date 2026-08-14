import SwiftUI
import AppKit

enum PocketTheme {
    static let background = adaptive(
        light: NSColor(calibratedRed: 0.965, green: 0.957, blue: 0.945, alpha: 1),
        dark: NSColor(calibratedRed: 0.055, green: 0.05, blue: 0.045, alpha: 1)
    )
    static let panel = adaptive(
        light: NSColor(calibratedRed: 0.925, green: 0.91, blue: 0.885, alpha: 1),
        dark: NSColor(calibratedRed: 0.105, green: 0.095, blue: 0.085, alpha: 1)
    )
    static let card = adaptive(
        light: NSColor(calibratedRed: 0.995, green: 0.99, blue: 0.98, alpha: 1),
        dark: NSColor(calibratedRed: 0.145, green: 0.13, blue: 0.115, alpha: 1)
    )
    static let input = adaptive(
        light: NSColor(calibratedRed: 0.90, green: 0.885, blue: 0.855, alpha: 1),
        dark: NSColor(calibratedRed: 0.105, green: 0.095, blue: 0.085, alpha: 1)
    )
    static let elevated = adaptive(
        light: NSColor(calibratedRed: 0.86, green: 0.84, blue: 0.80, alpha: 1),
        dark: NSColor(calibratedRed: 0.19, green: 0.17, blue: 0.145, alpha: 1)
    )
    /// Dominant gold sampled from the official PocketPass lock mark (#FDBF02).
    static let accent = Color(red: 253.0 / 255.0, green: 191.0 / 255.0, blue: 2.0 / 255.0)
    static let accentDeep = Color(red: 0.86, green: 0.55, blue: 0.0)
    static let primary = Color.primary
    static let muted = Color.secondary
    static let border = Color.primary.opacity(0.09)
    static let controlFill = Color.primary.opacity(0.065)
    static let inset = adaptive(
        light: NSColor(calibratedWhite: 0, alpha: 0.045),
        dark: NSColor(calibratedWhite: 0, alpha: 0.18)
    )
    static let primaryButton = accent
    static let primaryButtonText = Color.white

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(PocketTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(PocketTheme.border))
    }
}

extension View {
    func pocketPanel() -> some View { modifier(PanelModifier()) }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0
        let red, green, blue: Double
        if cleaned.count == 6 {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        } else {
            red = 0.5; green = 0.5; blue = 0.5
        }
        self.init(red: red, green: green, blue: blue)
    }

    var hexRGB: String {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return "888888" }
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return String(format: "%02X%02X%02X", red, green, blue)
    }
}
