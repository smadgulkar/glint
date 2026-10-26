import Foundation
import Combine

/// Free tier: a few AI answers or summaries per day. Pro is unlimited.
@MainActor
final class UsageMeter: ObservableObject {
    static let freeDailyLimit = 5

    @Published private(set) var usedToday: Int
    private let defaults = UserDefaults.standard
    private var day: String

    init() {
        let defaults = UserDefaults.standard // local: self isn't usable until every property is set
        let today = Self.dayKey()
        if defaults.string(forKey: "usageDay") == today {
            usedToday = defaults.integer(forKey: "usageCount")
        } else {
            usedToday = 0
        }
        day = today
    }

    var remainingToday: Int { max(0, Self.freeDailyLimit - usedToday) }

    func canUse(isPro: Bool) -> Bool {
        rollOverIfNeeded()
        return isPro || usedToday < Self.freeDailyLimit
    }

    func record(isPro: Bool) {
        guard !isPro else { return }
        rollOverIfNeeded()
        usedToday += 1
        defaults.set(day, forKey: "usageDay")
        defaults.set(usedToday, forKey: "usageCount")
    }

    func rollOverIfNeeded() {
        let today = Self.dayKey()
        guard today != day else { return }
        day = today
        usedToday = 0
        defaults.set(day, forKey: "usageDay")
        defaults.set(0, forKey: "usageCount")
    }

    private static func dayKey() -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
