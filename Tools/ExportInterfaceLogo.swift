import Foundation

let projectDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let sourceURL = projectDirectory
    .appendingPathComponent("Sources/PocketPass/Resources/PocketLogoMark.png")
let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("口袋密码-界面Logo-透明.png")

guard FileManager.default.fileExists(atPath: sourceURL.path) else {
    fatalError("找不到正式界面 Logo：\(sourceURL.path)")
}

let data = try Data(contentsOf: sourceURL)
try data.write(to: outputURL, options: .atomic)
print(outputURL.path)
