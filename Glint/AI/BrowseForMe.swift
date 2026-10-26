import Foundation
import Combine

/// Search for Me: search, read the top pages on the device, write one answer page.
@MainActor
final class BrowseForMeModel: ObservableObject {
    enum Phase: Equatable {
        case searching
        case reading(String)
        case writing
        case done
        case noAI(String)    // sources still shown, just no written answer
        case failed(String)
    }

    let query: String
    @Published private(set) var phase: Phase = .searching
    @Published private(set) var sources: [SearchResult] = []
    @Published private(set) var answer: BrowseAnswer?

    private var started = false
    private let sourceCount = 4

    init(query: String) {
        self.query = query
    }

    func run() async {
        guard !started else { return }
        started = true

        let results: [SearchResult]
        do {
            results = try await WebSearch.results(for: query)
        } catch {
            phase = .failed("Couldn't reach search results. Check your connection and try again.")
            return
        }
        sources = Array(results.prefix(sourceCount))

        if case .unavailable(let message) = AI.status {
            phase = .noAI(message)
            return
        }

        phase = .reading(sources.map(\.host).joined(separator: ", "))
        let texts = await readAll(sources)

        let aiSources = sources.enumerated().map { index, result in
            AI.Source(number: index + 1,
                      title: result.title,
                      host: result.host,
                      text: texts[index] ?? result.snippet) // fall back to the search snippet
        }

        phase = .writing
        do {
            answer = try await AI.answer(question: query, sources: aiSources)
            phase = .done
        } catch {
            phase = .noAI(AI.friendlyMessage(for: error))
        }
    }

    /// Loads all sources at once; each page has its own time limit.
    private func readAll(_ results: [SearchResult]) async -> [String?] {
        await withTaskGroup(of: (Int, String?).self, returning: [String?].self) { group in
            for (index, result) in results.enumerated() {
                let urlString = result.url
                group.addTask { @MainActor in
                    guard let url = URL(string: urlString) else { return (index, nil) }
                    let page = await PageReader.read(url)
                    return (index, page?.text)
                }
            }
            var texts = [String?](repeating: nil, count: results.count)
            for await (index, text) in group {
                texts[index] = text
            }
            return texts
        }
    }
}
