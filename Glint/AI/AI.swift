import Foundation
import FoundationModels

// MARK: - Structured outputs

@Generable
struct AnswerPoint {
    @Guide(description: "One clear sentence with a specific fact, number, name or recommendation")
    var text: String
    @Guide(description: "The number of the source this point comes from, for example 1 or 2")
    var source: Int
}

@Generable
struct BrowseAnswer {
    @Guide(description: "A direct answer to the question in one or two sentences")
    var headline: String
    @Guide(description: "Three to five key points that support or expand the answer")
    var points: [AnswerPoint]
    @Guide(description: "Two short follow-up questions the reader might ask next")
    var followUps: [String]
}

@Generable
struct PageSummary {
    @Guide(description: "What the page is about, in one sentence")
    var tldr: String
    @Guide(description: "Three to five of the most useful points on the page, one sentence each")
    var points: [String]
}

// MARK: - Model access

enum AIStatus: Equatable {
    case available
    case unavailable(String)
}

/// All generation runs on Apple's on-device model: no server, no per-answer cost.
@MainActor
enum AI {
    static var status: AIStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable("AI answers need an iPhone that supports Apple Intelligence (iPhone 15 Pro or newer).")
            case .appleIntelligenceNotEnabled:
                return .unavailable("Turn on Apple Intelligence in Settings to get AI answers.")
            case .modelNotReady:
                return .unavailable("Apple Intelligence is still downloading. Try again in a few minutes.")
            @unknown default:
                return .unavailable("AI answers aren't available on this iPhone right now.")
            }
        }
    }

    struct Source {
        let number: Int
        let title: String
        let host: String
        let text: String
    }

    private static let answerInstructions = """
    You are the search assistant inside a web browser. Answer the person's question using only \
    the numbered source excerpts you are given. Be concrete: prefer names, numbers and dates over \
    general statements. Cite the source number for every point. If the sources disagree, say so. \
    If the sources don't answer the question, say what they do cover instead of guessing.
    """

    private static let summaryInstructions = """
    You summarize web pages for a reader on a phone. Use only the page text you are given. \
    Be specific and plain. Skip navigation text, ads and cookie notices.
    """

    /// Writes the Search for Me answer. Retries with shorter excerpts if the context is too long.
    static func answer(question: String, sources: [Source], budgetPerSource: Int = 1500) async throws -> BrowseAnswer {
        var prompt = "Question: \(question)\n\nSources:\n"
        for source in sources {
            let excerpt = Excerpt.best(from: source.text, query: question, budget: budgetPerSource)
            prompt += "\n[\(source.number)] \(source.title) (\(source.host))\n\(excerpt)\n"
        }
        prompt += "\nAnswer the question using only these sources."

        let session = LanguageModelSession(instructions: answerInstructions)
        do {
            return try await session.respond(to: prompt, generating: BrowseAnswer.self).content
        } catch {
            if budgetPerSource > 400, !isGuardrail(error) {
                return try await answer(question: question, sources: sources, budgetPerSource: budgetPerSource / 2)
            }
            throw error
        }
    }

    static func summarize(title: String, text: String, budget: Int = 7000) async throws -> PageSummary {
        let body = String(text.prefix(budget))
        let prompt = "Page title: \(title)\n\nPage text:\n\(body)\n\nSummarize this page."
        let session = LanguageModelSession(instructions: summaryInstructions)
        do {
            return try await session.respond(to: prompt, generating: PageSummary.self).content
        } catch {
            if budget > 1500, !isGuardrail(error) {
                return try await summarize(title: title, text: text, budget: budget / 2)
            }
            throw error
        }
    }

    static func isGuardrail(_ error: Error) -> Bool {
        if let generationError = error as? LanguageModelSession.GenerationError,
           case .guardrailViolation = generationError {
            return true
        }
        return false
    }

    static func friendlyMessage(for error: Error) -> String {
        if isGuardrail(error) {
            return "Apple's on-device model won't write about this topic. You can still read the sources below."
        }
        return error.localizedDescription
    }
}
