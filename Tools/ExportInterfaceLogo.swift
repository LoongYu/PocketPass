import AppKit
import CoreGraphics
import Foundation

let pixelSize = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
guard let context = CGContext(
    data: nil,
    width: pixelSize,
    height: pixelSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo.rawValue
) else {
    fatalError("无法创建 Logo 画布")
}

let side = CGFloat(pixelSize)
let accent = CGColor(red: 1.0, green: 0.60, blue: 0.02, alpha: 1.0)

context.setStrokeColor(accent)
context.setLineWidth(side * 0.13)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: side * 0.25, y: side * 0.60))
context.addCurve(
    to: CGPoint(x: side * 0.75, y: side * 0.60),
    control1: CGPoint(x: side * 0.25, y: side * 0.88),
    control2: CGPoint(x: side * 0.75, y: side * 0.88)
)
context.strokePath()

let bodyRect = CGRect(x: side * 0.12, y: side * 0.12, width: side * 0.76, height: side * 0.41)
let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: side * 0.16, cornerHeight: side * 0.16, transform: nil)
context.setFillColor(accent)
context.addPath(bodyPath)
context.fillPath()

context.setBlendMode(.clear)
context.fillEllipse(in: CGRect(x: side * 0.43, y: side * 0.29, width: side * 0.14, height: side * 0.14))
let stemRect = CGRect(x: side * 0.475, y: side * 0.22, width: side * 0.05, height: side * 0.12)
context.addPath(CGPath(roundedRect: stemRect, cornerWidth: side * 0.025, cornerHeight: side * 0.025, transform: nil))
context.fillPath()

guard let image = context.makeImage() else { fatalError("无法生成 Logo 图像") }
let bitmap = NSBitmapImageRep(cgImage: image)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("无法编码 PNG")
}

let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("口袋密码-界面Logo-透明.png")
try pngData.write(to: outputURL, options: .atomic)
print(outputURL.path)
