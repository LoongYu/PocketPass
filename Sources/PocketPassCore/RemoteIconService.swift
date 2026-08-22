import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AppStoreSearchResult: Codable, Identifiable, Sendable {
    public let trackId: Int
    public let trackName: String
    public let artworkUrl100: URL
    public var id: Int { trackId }
}

private struct AppStoreResponse: Codable { let results: [AppStoreSearchResult] }

public enum AppStoreRegion: String, CaseIterable, Identifiable, Sendable {
    case china = "cn", unitedStates = "us", japan = "jp", unitedKingdom = "gb"
    case hongKong = "hk", germany = "de", southKorea = "kr", france = "fr", spain = "es"
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .china: "中国"; case .unitedStates: "美国"; case .japan: "日本"
        case .unitedKingdom: "英国"; case .hongKong: "香港"; case .germany: "德国"
        case .southKorea: "韩国"; case .france: "法国"; case .spain: "西班牙"
        }
    }
    public var flag: String {
        switch self {
        case .china: "🇨🇳"; case .unitedStates: "🇺🇸"; case .japan: "🇯🇵"
        case .unitedKingdom: "🇬🇧"; case .hongKong: "🇭🇰"; case .germany: "🇩🇪"
        case .southKorea: "🇰🇷"; case .france: "🇫🇷"; case .spain: "🇪🇸"
        }
    }
}

public enum RemoteIconService {
    public static func searchAppStore(_ term: String, region: AppStoreRegion = .china) async throws -> [AppStoreSearchResult] {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            .init(name: "term", value: term), .init(name: "entity", value: "software"),
            .init(name: "country", value: region.rawValue), .init(name: "limit", value: "24")
        ]
        let (data, response) = try await boundedData(for: URLRequest(url: components.url!), maximumBytes: 5_000_000)
        try validate(response: response)
        return try JSONDecoder().decode(AppStoreResponse.self, from: data).results
    }

    public static func downloadImage(_ url: URL) async throws -> Data {
        let (data, response) = try await boundedData(for: URLRequest(url: url), maximumBytes: 5_000_000)
        try validate(response: response)
        return data
    }

    public static func favicon(for input: String) async throws -> Data {
        let normalized = input.contains("://") ? input : "https://\(input)"
        guard let pageURL = URL(string: normalized), ["http", "https"].contains(pageURL.scheme?.lowercased() ?? "") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: pageURL, timeoutInterval: 10)
        request.setValue("text/html,application/xhtml+xml,image/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await boundedData(for: request, maximumBytes: 2_000_000)
        try validate(response: response)
        if (response as? HTTPURLResponse)?.mimeType?.hasPrefix("image/") == true { return data }
        let html = String(decoding: data.prefix(2_000_000), as: UTF8.self)
        if let iconURL = iconURL(from: html, relativeTo: pageURL), let icon = try? await downloadImage(iconURL) { return icon }
        return try await downloadImage(URL(string: "/favicon.ico", relativeTo: pageURL)!.absoluteURL)
    }

    private static func iconURL(from html: String, relativeTo base: URL) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: #"<link\b[^>]*>"#, options: [.caseInsensitive]) else { return nil }
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html) else { continue }
            let tag = String(html[range])
            guard tag.range(of: #"rel\s*=\s*[\"'][^\"']*icon"#, options: [.regularExpression, .caseInsensitive]) != nil,
                  let href = tag.range(of: #"href\s*=\s*[\"'][^\"']+[\"']"#, options: [.regularExpression, .caseInsensitive]) else { continue }
            let attribute = String(tag[href])
            guard let first = attribute.firstIndex(where: { $0 == "\"" || $0 == "'" }),
                  let last = attribute.lastIndex(where: { $0 == "\"" || $0 == "'" }), first < last else { continue }
            if let url = URL(string: String(attribute[attribute.index(after: first)..<last]), relativeTo: base)?.absoluteURL,
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") { return url }
        }
        return nil
    }

    private static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
    }

    private static func boundedData(for request: URLRequest, maximumBytes: Int) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if response.expectedContentLength > Int64(maximumBytes) { throw URLError(.dataLengthExceedsMaximum) }
        var data = Data()
        data.reserveCapacity(min(maximumBytes, max(0, Int(response.expectedContentLength))))
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        return (data, response)
    }
}
