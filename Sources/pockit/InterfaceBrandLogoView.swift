import SwiftUI

struct InterfaceBrandLogoView: View {
    var size: CGFloat = 24

    var body: some View {
        Canvas { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let originX = (canvasSize.width - side) / 2
            let originY = (canvasSize.height - side) / 2

            var shackle = Path()
            shackle.addArc(
                center: CGPoint(x: originX + side * 0.50, y: originY + side * 0.38),
                radius: side * 0.25,
                startAngle: .degrees(190),
                endAngle: .degrees(350),
                clockwise: false
            )
            context.stroke(
                shackle,
                with: .color(PocketTheme.accent),
                style: StrokeStyle(lineWidth: side * 0.13, lineCap: .round, lineJoin: .round)
            )

            let bodyRect = CGRect(
                x: originX + side * 0.12,
                y: originY + side * 0.47,
                width: side * 0.76,
                height: side * 0.41
            )
            let lockBody = Path(roundedRect: bodyRect, cornerRadius: side * 0.16)
            context.fill(lockBody, with: .color(PocketTheme.accent))

            context.blendMode = .destinationOut
            var keyhole = Path()
            keyhole.addEllipse(in: CGRect(
                x: originX + side * 0.43,
                y: originY + side * 0.57,
                width: side * 0.14,
                height: side * 0.14
            ))
            keyhole.addRoundedRect(in: CGRect(
                x: originX + side * 0.475,
                y: originY + side * 0.66,
                width: side * 0.05,
                height: side * 0.12
            ), cornerSize: CGSize(width: side * 0.025, height: side * 0.025))
            context.fill(keyhole, with: .color(.black))
        }
            .frame(width: size, height: size)
            .background(.clear)
            .accessibilityLabel("口袋密码")
    }
}
