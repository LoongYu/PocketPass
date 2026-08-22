import Foundation
import PocketPassCore

typealias AppStoreSearchResult = PocketPassCore.AppStoreSearchResult
typealias AppStoreRegion = PocketPassCore.AppStoreRegion

enum RemoteIconService {
    static func searchAppStore(_ term: String, region: AppStoreRegion = .china) async throws -> [AppStoreSearchResult] {
        try await PocketPassCore.RemoteIconService.searchAppStore(term, region: region)
    }
    static func downloadImage(_ url: URL) async throws -> Data {
        try await PocketPassCore.RemoteIconService.downloadImage(url)
    }
    static func favicon(for input: String) async throws -> Data {
        try await PocketPassCore.RemoteIconService.favicon(for: input)
    }
}
