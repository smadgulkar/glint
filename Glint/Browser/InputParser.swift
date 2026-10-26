import Foundation

enum InputParser {
    /// Returns a URL when the input looks like a web address, nil when it's a search.
    static func url(from input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(" ") else { return nil }

        if let url = URL(string: text),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           url.host() != nil {
            return url
        }

        // "example.com", "news.ycombinator.com/item?id=1"
        guard text.contains("."),
              let url = URL(string: "https://" + text),
              let host = url.host(),
              host.contains("."),
              let tld = host.split(separator: ".").last,
              tld.count >= 2,
              tld.allSatisfy({ $0.isLetter }) else { return nil }
        return url
    }

    /// Every distinct web link in a block of pasted text (used to import tabs).
    static func urls(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        var seen = Set<String>()
        return detector.matches(in: text, options: [], range: range)
            .compactMap(\.url)
            .filter { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
            .filter { seen.insert($0.absoluteString).inserted }
    }
}
