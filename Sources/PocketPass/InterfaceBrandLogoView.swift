import AppKit
import SwiftUI

struct InterfaceBrandLogoView: View {
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let logo = PocketBrandAssets.interfaceMark {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "lock.open.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(PocketTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .background(.clear)
        .accessibilityLabel("口袋密码")
    }
}

private enum PocketBrandAssets {
    static let interfaceMark: NSImage? = {
        let bundles = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let url = bundle.url(forResource: "PocketLogoMark", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        guard let executableURL = Bundle.main.executableURL else { return nil }
        let executableDirectory = executableURL.deletingLastPathComponent()
        let candidates = [
            executableDirectory.deletingLastPathComponent().appendingPathComponent("Resources/PocketLogoMark.png"),
            executableDirectory.appendingPathComponent("PocketPass_PocketPass.bundle/PocketLogoMark.png"),
            executableDirectory.deletingLastPathComponent().appendingPathComponent("PocketPass_PocketPass.bundle/PocketLogoMark.png")
        ]
        return candidates.lazy.compactMap(NSImage.init(contentsOf:)).first
    }()
}
