import AppKit
import SwiftUI

struct CategoryColorPalette: View {
    @Binding var color: Color
    @Binding var usesCustomColor: Bool

    static let presetHexes = [
        "F59E0B", "EF5B5B", "5792E8", "8B6FD6", "4DBB8A", "E45D9B",
        "55B8C8", "A87B52", "5969C9", "55C7B0", "E5B83B", "888888"
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(38)), count: 10), spacing: 10) {
            RoundColorWell(color: $color, usesCustomColor: $usesCustomColor)
                .frame(width: 30, height: 30)
                .overlay {
                    if usesCustomColor {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("自选颜色")

            ForEach(Self.presetHexes, id: \.self) { hex in
                Button {
                    color = Color(hex: hex)
                    usesCustomColor = false
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if !usesCustomColor, color.hexRGB == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RoundColorWell: View {
    @Binding var color: Color
    @Binding var usesCustomColor: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                        center: .center
                    )
                )
            Circle()
                .fill(color)
                .padding(4)
            NativeColorWell(color: $color, usesCustomColor: $usesCustomColor)
        }
        .clipShape(Circle())
        .contentShape(Circle())
    }
}

@MainActor
private struct NativeColorWell: NSViewRepresentable {
    @Binding var color: Color
    @Binding var usesCustomColor: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSColorWell {
        let colorWell = NSColorWell()
        colorWell.colorWellStyle = .minimal
        colorWell.isBordered = false
        colorWell.color = NSColor(color)
        colorWell.alphaValue = 0.01
        colorWell.target = context.coordinator
        colorWell.action = #selector(Coordinator.colorChanged(_:))
        return colorWell
    }

    func updateNSView(_ colorWell: NSColorWell, context: Context) {
        context.coordinator.parent = self
        let newColor = NSColor(color)
        if colorWell.color != newColor {
            colorWell.color = newColor
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: NativeColorWell

        init(parent: NativeColorWell) {
            self.parent = parent
        }

        @objc func colorChanged(_ sender: NSColorWell) {
            parent.color = Color(nsColor: sender.color)
            parent.usesCustomColor = true
        }
    }
}
