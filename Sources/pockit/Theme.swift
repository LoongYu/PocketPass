import SwiftUI
import AppKit

enum PocketTheme {
    static let background = Color(red: 0.055, green: 0.05, blue: 0.045)
    static let panel = Color(red: 0.105, green: 0.095, blue: 0.085)
    static let card = Color(red: 0.145, green: 0.13, blue: 0.115)
    static let input = Color(red: 0.105, green: 0.095, blue: 0.085)
    static let elevated = Color(red: 0.19, green: 0.17, blue: 0.145)
    static let accent = Color(red: 1.0, green: 0.60, blue: 0.02)
    static let muted = Color.white.opacity(0.52)
}

struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(PocketTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.035)))
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
