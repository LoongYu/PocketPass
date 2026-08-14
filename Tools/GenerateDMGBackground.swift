import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "dmg-background.png")
let size = NSSize(width: 720, height: 440)
let image = NSImage(size: size)

image.lockFocus()
NSColor(calibratedWhite: 0.075, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let title = "安装口袋密码"
let subtitle = "将口袋密码拖到 Applications 文件夹"
let titleStyle: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .bold),
    .foregroundColor: NSColor.white
]
let subtitleStyle: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 16, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.68, alpha: 1)
]
title.draw(at: NSPoint(x: 36, y: 380), withAttributes: titleStyle)
subtitle.draw(at: NSPoint(x: 36, y: 350), withAttributes: subtitleStyle)

let accent = NSColor(calibratedRed: 1, green: 0.63, blue: 0, alpha: 1)
accent.setStroke()
let arrow = NSBezierPath()
arrow.lineWidth = 8
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 315, y: 218))
arrow.line(to: NSPoint(x: 405, y: 218))
arrow.move(to: NSPoint(x: 380, y: 243))
arrow.line(to: NSPoint(x: 405, y: 218))
arrow.line(to: NSPoint(x: 380, y: 193))
arrow.stroke()

let footer = "V1.0(1) · macOS 26 或更高版本"
footer.draw(at: NSPoint(x: 36, y: 26), withAttributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.46, alpha: 1)
])
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("无法生成 DMG 背景图")
}
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: outputURL, options: .atomic)
