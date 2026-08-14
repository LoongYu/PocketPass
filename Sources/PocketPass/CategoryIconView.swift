import SwiftUI

struct CategoryIconView: View {
    let symbol: String
    let data: Data?
    let color: Color
    var size: CGFloat = 48
    var cornerRadius: CGFloat = 14

    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(color.gradient)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
