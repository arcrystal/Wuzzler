import Foundation

/// Centralized streak and daily progress computation.
/// Reads only counted DailyMeta UserDefaults entries for streaks/statistics.
/// Practice archive sessions are stored separately and surfaced only as archive status.
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
        let today = dayString(from: PuzzleDay.today)
        return DailyProgress(
            diagoneCompleted: isCountedFinished(prefix: "diagone", day: today),
            rhymeAGramsCompleted: isCountedFinished(prefix: "rhymeagrams", day: today),
            tumblePunsCompleted: isCountedFinished(prefix: "tumblepuns", day: today)
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
        let prefix = PuzzleDay.storagePrefix(for: game)
        let metaPrefix = "\(prefix)_meta_"
        let today = dayString(from: PuzzleDay.today)
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys

        for key in allKeys where key.hasPrefix(metaPrefix) {
            let dateStr = String(key.dropFirst(metaPrefix.count))
            // Skip today — we're comparing against previous days
            guard dateStr != today else { continue }
            guard let json = metaJSON(forKey: key),
                  !isPractice(json),
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
            guard let json = metaJSON(forKey: key),
                  !isPractice(json),
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

    // MARK: - Puzzle Status (for Archive)

    enum PuzzleStatus {
        case notStarted
        case inProgress(elapsed: TimeInterval)
        case completed(time: TimeInterval)
    }

    static func puzzleStatus(game: GameType, day: String) -> PuzzleStatus {
        let prefix = PuzzleDay.storagePrefix(for: game)
        let countedKey = "\(prefix)_meta_\(day)"
        let practiceKey = "\(prefix)_practice_meta_\(day)"

        if let counted = status(forMetaKey: countedKey), case .completed = counted {
            return counted
        }
        if let practice = status(forMetaKey: practiceKey), case .completed = practice {
            return practice
        }
        if let counted = status(forMetaKey: countedKey), case .inProgress = counted {
            return counted
        }
        if let practice = status(forMetaKey: practiceKey) {
            return practice
        }
        return .notStarted
    }

    static func finishTime(game: GameType, on date: Date) -> TimeInterval? {
        let prefix = PuzzleDay.storagePrefix(for: game)
        let day = dayString(from: date)
        let key = "\(prefix)_meta_\(day)"
        guard let json = metaJSON(forKey: key),
              !isPractice(json),
              let finished = json["finished"] as? Bool, finished,
              let finishTime = json["finishTime"] as? Double, finishTime > 0 else { return nil }
        return finishTime
    }

    static func dailySweepFinishTimes(on date: Date) -> [GameType: TimeInterval]? {
        var times: [GameType: TimeInterval] = [:]
        for game in GameType.allCases {
            guard let time = finishTime(game: game, on: date) else { return nil }
            times[game] = time
        }
        return times
    }

    static func personalBestTime(game: GameType) -> TimeInterval? {
        let prefix = PuzzleDay.storagePrefix(for: game)
        let metaPrefix = "\(prefix)_meta_"
        return UserDefaults.standard.dictionaryRepresentation().keys.compactMap { key -> TimeInterval? in
            guard key.hasPrefix(metaPrefix),
                  let json = metaJSON(forKey: key),
                  !isPractice(json),
                  let finished = json["finished"] as? Bool, finished,
                  let finishTime = json["finishTime"] as? Double, finishTime > 0 else { return nil }
            return finishTime
        }
        .min()
    }

    static func dailySweepCount() -> Int {
        let prefixes = GameType.allCases.map { "\(PuzzleDay.storagePrefix(for: $0))_meta_" }
        var allDates = Set<String>()
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            for prefix in prefixes where key.hasPrefix(prefix) {
                allDates.insert(String(key.dropFirst(prefix.count)))
            }
        }

        return allDates.reduce(0) { count, day in
            let allDone = GameType.allCases.allSatisfy { game in
                isCountedFinished(prefix: PuzzleDay.storagePrefix(for: game), day: day)
            }
            return count + (allDone ? 1 : 0)
        }
    }

    private static func status(forMetaKey key: String) -> PuzzleStatus? {
        guard let json = metaJSON(forKey: key) else { return nil }
        let finished = json["finished"] as? Bool ?? false
        let elapsed = json["elapsedTime"] as? Double ?? 0
        let finishTime = json["finishTime"] as? Double ?? 0
        if finished {
            return .completed(time: finishTime)
        }
        let started = json["started"] as? Bool ?? false
        if started {
            return .inProgress(elapsed: elapsed)
        }
        return nil
    }

    // MARK: - Internals

    private static func dayString(from date: Date) -> String {
        PuzzleDay.storageKey(for: date)
    }

    private static func isCountedFinished(prefix: String, day: String) -> Bool {
        let key = "\(prefix)_meta_\(day)"
        guard let json = metaJSON(forKey: key),
              !isPractice(json),
              let finished = json["finished"] as? Bool else { return false }
        return finished
    }

    private static func metaJSON(forKey key: String) -> [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func isPractice(_ json: [String: Any]) -> Bool {
        json["isPractice"] as? Bool ?? false
    }

    private static func currentStreak(prefix: String) -> Int {
        var streak = 0
        var date = PuzzleDay.today
        while true {
            let ds = dayString(from: date)
            if isCountedFinished(prefix: prefix, day: ds) {
                streak += 1
                date = PuzzleDay.addDays(-1, to: date)
            } else {
                break
            }
        }
        return streak
    }

    private static func combinedStreakInfo() -> (current: Int, best: Int) {
        // Walk backwards from today for current
        var current = 0
        var date = PuzzleDay.today
        while true {
            let ds = dayString(from: date)
            let allDone = isCountedFinished(prefix: "diagone", day: ds)
                       && isCountedFinished(prefix: "rhymeagrams", day: ds)
                       && isCountedFinished(prefix: "tumblepuns", day: ds)
            if allDone {
                current += 1
                date = PuzzleDay.addDays(-1, to: date)
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

        guard let earliest = allDates.compactMap({ PuzzleDay.date(fromStorageKey: $0) }).min(),
              let latest = allDates.compactMap({ PuzzleDay.date(fromStorageKey: $0) }).max() else {
            return (current, current)
        }

        var best = 0
        var streak = 0
        var d = earliest
        while d <= latest {
            let ds = dayString(from: d)
            let allDone = isCountedFinished(prefix: "diagone", day: ds)
                       && isCountedFinished(prefix: "rhymeagrams", day: ds)
                       && isCountedFinished(prefix: "tumblepuns", day: ds)
            if allDone {
                streak += 1
                best = max(best, streak)
            } else {
                streak = 0
            }
            d = PuzzleDay.addDays(1, to: d)
        }

        return (current, max(best, current))
    }
}
