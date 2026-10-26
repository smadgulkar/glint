import Foundation
import Combine

enum SearchEngine: String, CaseIterable, Identifiable {
    case google, duckduckgo, bing

    var id: String { rawValue }

    var name: String {
        switch self {
        case .google: return "Google"
        case .duckduckgo: return "DuckDuckGo"
        case .bing: return "Bing"
        }
    }

    func url(for query: String) -> URL {
        let base: String
        switch self {
        case .google: base = "https://www.google.com/search"
        case .duckduckgo: base = "https://duckduckgo.com/"
        case .bing: base = "https://www.bing.com/search"
        }
        var components = URLComponents(string: base)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        // URLComponents leaves "+" alone, but search engines read it as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }
}

/// What the Return key does when the input isn't a web address.
enum ReturnAction: String, CaseIterable, Identifiable {
    case searchForMe, webSearch
    var id: String { rawValue }
    var name: String {
        switch self {
        case .searchForMe: return "Search for Me (AI answer)"
        case .webSearch: return "Regular web search"
        }
    }
}

enum ArchiveInterval: String, CaseIterable, Identifiable {
    case twelveHours, day, week, never
    var id: String { rawValue }
    var name: String {
        switch self {
        case .twelveHours: return "After 12 hours"
        case .day: return "After 24 hours"
        case .week: return "After 7 days"
        case .never: return "Never"
        }
    }
    var seconds: TimeInterval {
        switch self {
        case .twelveHours: return 12 * 3600
        case .day: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .never: return 0
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var engine: SearchEngine {
        didSet { defaults.set(engine.rawValue, forKey: "engine") }
    }
    @Published var returnAction: ReturnAction {
        didSet { defaults.set(returnAction.rawValue, forKey: "returnAction") }
    }
    @Published var archiveInterval: ArchiveInterval {
        didSet { defaults.set(archiveInterval.rawValue, forKey: "archiveInterval") }
    }
    @Published var blockAds: Bool {
        didSet {
            defaults.set(blockAds, forKey: "blockAds")
            ContentBlocker.shared.setEnabled(blockAds)
        }
    }

    init() {
        let defaults = UserDefaults.standard // local: self isn't usable until every property is set
        engine = SearchEngine(rawValue: defaults.string(forKey: "engine") ?? "") ?? .google
        returnAction = ReturnAction(rawValue: defaults.string(forKey: "returnAction") ?? "") ?? .searchForMe
        archiveInterval = ArchiveInterval(rawValue: defaults.string(forKey: "archiveInterval") ?? "") ?? .day
        blockAds = defaults.object(forKey: "blockAds") as? Bool ?? true
    }
}
