import SwiftUI
import ImageIO

enum IOSAppearance: String, CaseIterable, Identifiable {
    case dark = "深色"
    case light = "亮色"
    case system = "跟随系统"

    var id: Self { self }
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

enum IOSTheme {
    static let accent = Color(red: 253 / 255, green: 191 / 255, blue: 2 / 255)
    static let accentDeep = Color(red: 0.78, green: 0.48, blue: 0)
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.045, green: 0.041, blue: 0.037, alpha: 1)
            : UIColor(red: 0.965, green: 0.957, blue: 0.945, alpha: 1)
    })
    static let panel = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.105, green: 0.095, blue: 0.085, alpha: 1)
            : UIColor(red: 0.995, green: 0.99, blue: 0.98, alpha: 1)
    })
    static let input = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.135, blue: 0.12, alpha: 1)
            : UIColor(red: 0.91, green: 0.895, blue: 0.87, alpha: 1)
    })
    static let muted = Color.secondary
}

struct IOSModalHeader: View {
    let title: LocalizedStringKey
    let canSave: Bool
    let cancel: () -> Void
    let save: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.headline)

            HStack {
                Button(action: cancel) {
                    Text("取消")
                        .fontWeight(.semibold)
                        .frame(width: 86, height: 48)
                        .background(IOSTheme.panel, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: save) {
                    Text("保存")
                        .fontWeight(.bold)
                        .foregroundStyle(canSave ? .black : .secondary)
                        .frame(width: 86, height: 48)
                        .background(canSave ? IOSTheme.accent : Color.secondary.opacity(0.15), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(IOSTheme.background)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
    }
}

struct IOSPanel: ViewModifier {
    var radius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(IOSTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            }
    }
}

extension View {
    func iosPanel(radius: CGFloat = 24) -> some View {
        modifier(IOSPanel(radius: radius))
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0x888888
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var rgbHex: String {
        let color = UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "888888" }
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

struct IOSBrandMark: View {
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let image = Self.brandImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "lock.open.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(IOSTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("口袋密码")
    }

    private static let brandImage: UIImage? = {
        guard let url = Bundle.main.url(forResource: "PocketLogoMark", withExtension: "png") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }()
}

enum IOSImageProcessor {
    static func normalizedIconData(_ data: Data, maximumDimension: CGFloat = 512, maximumBytes: Int = 2_000_000) -> Data? {
        guard safePixelDimensions(data) else { return nil }
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, maximumDimension / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        format.scale = 1
        let normalizedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        if let png = normalizedImage.pngData(), png.count <= maximumBytes { return png }
        for quality in stride(from: 0.9, through: 0.45, by: -0.1) {
            if let jpeg = normalizedImage.jpegData(compressionQuality: quality), jpeg.count <= maximumBytes { return jpeg }
        }
        return nil
    }

    private static func safePixelDimensions(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return false }
        return width > 0 && height > 0 && width <= 8_192 && height <= 8_192 && width * height <= 40_000_000
    }
}
