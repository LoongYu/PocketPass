import Foundation

struct AppStoreSearchResult: Codable, Identifiable {
    let trackId: Int
    let trackName: String
    let artworkUrl100: URL
    var id: Int { trackId }
}

private struct AppStoreResponse: Codable {
    let results: [AppStoreSearchResult]
}

enum AppStoreRegion: String, CaseIterable, Identifiable {
    case china = "cn"
    case unitedStates = "us"
    case japan = "jp"
    case unitedKingdom = "gb"
    case hongKong = "hk"
    case germany = "de"
    case southKorea = "kr"
    case france = "fr"
    case spain = "es"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .china: "中国"
        case .unitedStates: "美国"
        case .japan: "日本"
        case .unitedKingdom: "英国"
        case .hongKong: "香港"
        case .germany: "德国"
        case .southKorea: "韩国"
        case .france: "法国"
        case .spain: "西班牙"
        }
    }

    var flag: String {
        switch self {
        case .china: "🇨🇳"
        case .unitedStates: "🇺🇸"
        case .japan: "🇯🇵"
        case .unitedKingdom: "🇬🇧"
        case .hongKong: "🇭🇰"
        case .germany: "🇩🇪"
        case .southKorea: "🇰🇷"
        case .france: "🇫🇷"
        case .spain: "🇪🇸"
        }
    }
}

enum RemoteIconService {
    static func searchAppStore(_ term: String, region: AppStoreRegion = .china) async throws -> [AppStoreSearchResult] {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            .init(name: "term", value: term), .init(name: "entity", value: "software"),
            .init(name: "country", value: region.rawValue), .init(name: "limit", value: "24")
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(AppStoreResponse.self, from: data).results
    }

    static func downloadImage(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)
        guard data.count <= 5_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
        return data
    }

    static func favicon(for input: String) async throws -> Data {
        let normalized = input.contains("://") ? input : "https://\(input)"
        guard let pageURL = URL(string: normalized), ["http", "https"].contains(pageURL.scheme?.lowercased() ?? "") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: pageURL, timeoutInterval: 10)
        request.setValue("text/html,application/xhtml+xml,image/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        if (response as? HTTPURLResponse)?.mimeType?.hasPrefix("image/") == true { return data }

        let html = String(decoding: data.prefix(2_000_000), as: UTF8.self)
        if let iconURL = iconURL(from: html, relativeTo: pageURL),
           let icon = try? await downloadImage(iconURL) { return icon }

        let root = URL(string: "/favicon.ico", relativeTo: pageURL)!.absoluteURL
        return try await downloadImage(root)
    }

    private static func iconURL(from html: String, relativeTo base: URL) -> URL? {
        let pattern = #"<link\b[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range) {
            guard let swiftRange = Range(match.range, in: html) else { continue }
            let tag = String(html[swiftRange])
            guard tag.range(of: #"rel\s*=\s*["'][^"']*icon"#, options: [.regularExpression, .caseInsensitive]) != nil,
                  let hrefRange = tag.range(of: #"href\s*=\s*["'][^"']+["']"#, options: [.regularExpression, .caseInsensitive]) else { continue }
            let attribute = String(tag[hrefRange])
            guard let firstQuote = attribute.firstIndex(where: { $0 == "\"" || $0 == "'" }),
                  let lastQuote = attribute.lastIndex(where: { $0 == "\"" || $0 == "'" }), firstQuote < lastQuote else { continue }
            let value = String(attribute[attribute.index(after: firstQuote)..<lastQuote])
            if let url = URL(string: value, relativeTo: base)?.absoluteURL,
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") { return url }
        }
        return nil
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        guard data.count <= 5_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
    }
}
