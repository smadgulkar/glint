import Foundation

struct SearchResult: Identifiable, Decodable, Hashable {
    let url: String
    let title: String
    let snippet: String

    var id: String { url }

    var host: String {
        URL(string: url)?.host()?.replacingOccurrences(of: "www.", with: "") ?? url
    }
}

/// Gets result links by loading DuckDuckGo's lightweight HTML results page on the device.
/// No API key and no server of ours. To swap in a paid search API later, change only this file.
@MainActor
enum WebSearch {
    /// Sites whose pages are mostly video or behind a login, so there is little text to read.
    private static let skipHosts = [
        "youtube.com", "youtu.be", "tiktok.com", "instagram.com", "facebook.com",
        "x.com", "twitter.com", "pinterest.com", "linkedin.com",
    ]

    static func results(for query: String) async throws -> [SearchResult] {
        var components = URLComponents(string: "https://html.duckduckgo.com/html/")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { throw ReaderError.noResults }

        let reader = PageReader()
        try await reader.load(url, timeout: 8)
        guard let json = try await reader.evaluate(Scripts.searchResults) as? String else {
            throw ReaderError.noResults
        }
        let all = try JSONDecoder().decode([SearchResult].self, from: Data(json.utf8))
        let usable = all.filter { result in
            let host = result.host.lowercased()
            let blocked = skipHosts.contains { host == $0 || host.hasSuffix("." + $0) }
            return !blocked && !result.url.lowercased().hasSuffix(".pdf")
        }
        guard !usable.isEmpty else { throw ReaderError.noResults }
        return usable
    }
}
