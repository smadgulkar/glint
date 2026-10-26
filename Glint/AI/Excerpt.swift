import Foundation

/// Picks the paragraphs of a page most related to the question, within a character budget.
/// The on-device model has a small context window (about 4,000 tokens), so this
/// matters more than anything else for answer quality.
enum Excerpt {
    private static let stopWords: Set<String> = [
        "the", "and", "for", "are", "what", "which", "who", "how", "why", "when", "where",
        "does", "did", "can", "should", "with", "from", "that", "this", "best", "you", "your",
        "about", "into", "have", "has", "was", "were", "will", "there", "their", "them", "than",
    ]

    static func terms(in query: String) -> Set<String> {
        let words = query.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        return Set(words.filter { $0.count > 2 && !stopWords.contains($0) })
    }

    static func best(from text: String, query: String, budget: Int) -> String {
        let paragraphs = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 40 }
        guard !paragraphs.isEmpty else { return String(text.prefix(budget)) }

        let queryTerms = terms(in: query)
        let scored: [(index: Int, score: Int)] = paragraphs.enumerated().map { index, paragraph in
            let lower = paragraph.lowercased()
            let hits = queryTerms.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }
            let leadBonus = index < 3 ? 2 : 0 // opening paragraphs usually carry the gist
            return (index, hits * 10 + leadBonus)
        }

        var chosen: [Int] = []
        var used = 0
        for item in scored.sorted(by: { $0.score > $1.score }) {
            let length = paragraphs[item.index].count
            if used + length <= budget {
                chosen.append(item.index)
                used += length
            } else if chosen.isEmpty {
                chosen.append(item.index) // one long paragraph: take its start
                used = budget
            }
            if used >= budget { break }
        }

        // Keep the page's own order so the excerpt still reads naturally.
        return chosen.sorted()
            .map { String(paragraphs[$0].prefix(budget)) }
            .joined(separator: "\n")
    }
}
