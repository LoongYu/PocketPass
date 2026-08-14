import Foundation

@main
struct RemoteIconSmoke {
    static func main() async throws {
        let apps = try await RemoteIconService.searchAppStore("微信")
        precondition(!apps.isEmpty)
        let artwork = try await RemoteIconService.downloadImage(apps[0].artworkUrl100)
        precondition(artwork.count > 1_000)
        let favicon = try await RemoteIconService.favicon(for: "https://www.apple.com.cn")
        precondition(favicon.count > 100)
        print("remote-icon-smoke-ok \(apps.count) \(artwork.count) \(favicon.count)")
    }
}
