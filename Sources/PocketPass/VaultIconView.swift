import SwiftUI

struct VaultIconView: View {
    let symbol: String
    let data: Data?
    var size: CGFloat = 42
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: symbol).font(.system(size: size * 0.42, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PocketTheme.accent)
                    .foregroundStyle(.black)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
