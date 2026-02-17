import Foundation

/// Centralized streak and daily progress computation.
/// Reads from the existing DailyMeta UserDefaults entries — no new storage required.
enum StreakManager {

    // MARK: - Public Types

    struct DailyProgress {
        let diagoneCompleted: Bool
        let rhymeAGramsCompleted: Bool
        let tumblePunsCompleted: Bool

        var completedCount: Int {
            [diagoneCompleted, rhymeAGramsCompleted, tumblePunsCompleted].filter { $0 }.count
        }
        var allComplete: Bool { completedCount == 3 }
    }

    struct StreakInfo {
        /// Per-game current streak (consecutive days with that game finished)
        let diagoneStreak: Int
        let rhymeAGramsStreak: Int
        let tumblePunsStreak: Int
        /// Combined streak: consecutive days where ALL 3 games were completed
        let combinedStreak: Int
        /// Best combined streak ever
        let bestCombinedStreak: Int
    }

    // MARK: - Today's Progress

    static func todayProgress() -> DailyProgress {
        let today = dayString(from: Date())
        return DailyProgress(
            diagoneCompleted: isFinished(prefix: "diagone", day: today),
            rhymeAGramsCompleted: isFinished(prefix: "rhymeagrams", day: today),
            tumblePunsCompleted: isFinished(prefix: "tumblepuns", day: today)
        )
    }

    // MARK: - Streak Computation

    static func streakInfo() -> StreakInfo {
        let diagone = currentStreak(prefix: "diagone")
        let rhyme = currentStreak(prefix: "rhymeagrams")
        let tumble = currentStreak(prefix: "tumblepuns")
        let (combined, best) = combinedStreakInfo()
        return StreakInfo(
            diagoneStreak: diagone,
            rhymeAGramsStreak: rhyme,
            tumblePunsStreak: tumble,
            combinedStreak: combined,
            bestCombinedStreak: best
        )
    }

    /// The best (longest) combined streak — used for milestone detection.
    static var bestCombinedStreak: Int {
        combinedStreakInfo().best
    }

    // MARK: - Personal Best Detection

    /// Returns true if the given finish time is a new personal best for the game.
    static func isPersonalBest(game: GameType, time: TimeInterval) -> Bool {
        guard time > 0 else { return false }
        let prefix: String
        switch game {
        case .diagone: prefix = "diagone"
        case .rhymeAGrams: prefix = "rhymeagrams"
        case .tumblePuns: prefix = "tumblepuns"
        }
        let metaPrefix = "\(prefix)_meta_"
        let today = dayString(from: Date())
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys

        for key in allKeys where key.hasPrefix(metaPrefix) {
            let dateStr = String(key.dropFirst(metaPrefix.count))
            // Skip today — we're comparing against previous days
            guard dateStr != today else { continue }
            guard let data = UserDefaults.standard.data(forKey: key),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let finished = json["finished"] as? Bool, finished,
                  let ft = json["finishTime"] as? Double, ft > 0 else { continue }
            if ft <= time { return false }
        }
        // If we get here, no previous day had a faster time
        // But make sure there IS at least one previous finished game (otherwise first win isn't a "personal best")
        let hasPrevious = allKeys.contains { key in
            guard key.hasPrefix(metaPrefix) else { return false }
            let dateStr = String(key.dropFirst(metaPrefix.count))
            guard dateStr != today else { return false }
            guard let data = UserDefaults.standard.data(forKey: key),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let finished = json["finished"] as? Bool else { return false }
            return finished
        }
        return hasPrevious
    }

    // MARK: - Greeting

    static var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Happy puzzling"
        }
    }

    // MARK: - Internals

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dayString(from date: Date) -> String {
        fmt.string(from: date)
    }

    private static func isFinished(prefix: String, day: String) -> Bool {
        let key = "\(prefix)_meta_\(day)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let finished = json["finished"] as? Bool else { return false }
        return finished
    }

    private static func currentStreak(prefix: String) -> Int {
        var streak = 0
        var date = Date()
        while true {
            let ds = dayString(from: date)
            if isFinished(prefix: prefix, day: ds) {
                streak += 1
                date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
            } else {
                break
            }
        }
        return streak
    }

    private static func combinedStreakInfo() -> (current: Int, best: Int) {
        // Walk backwards from today for current
        var current = 0
        var date = Date()
        while true {
            let ds = dayString(from: date)
            let allDone = isFinished(prefix: "diagone", day: ds)
                       && isFinished(prefix: "rhymeagrams", day: ds)
                       && isFinished(prefix: "tumblepuns", day: ds)
            if allDone {
                current += 1
                date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
            } else {
                break
            }
        }

        // For best combined streak, scan all meta keys to find date range, then walk
        let prefixes = ["diagone_meta_", "rhymeagrams_meta_", "tumblepuns_meta_"]
        var allDates = Set<String>()
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            for p in prefixes where key.hasPrefix(p) {
                allDates.insert(String(key.dropFirst(p.count)))
            }
        }

        guard let earliest = allDates.compactMap({ fmt.date(from: $0) }).min(),
              let latest = allDates.compactMap({ fmt.date(from: $0) }).max() else {
            return (current, current)
        }

        var best = 0
        var streak = 0
        var d = earliest
        while d <= latest {
            let ds = dayString(from: d)
            let allDone = isFinished(prefix: "diagone", day: ds)
                       && isFinished(prefix: "rhymeagrams", day: ds)
                       && isFinished(prefix: "tumblepuns", day: ds)
            if allDone {
                streak += 1
                best = max(best, streak)
            } else {
                streak = 0
            }
            d = Calendar.current.date(byAdding: .day, value: 1, to: d)!
        }

        return (current, max(best, current))
    }
}
