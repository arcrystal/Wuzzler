import Foundation

struct ArchiveDay: Identifiable {
    let id: String          // yyyy-MM-dd
    let date: Date
    let dayOfMonth: Int
    let isToday: Bool
    let isFirstOfMonth: Bool
    let monthAbbreviation: String
    let status: StreakManager.PuzzleStatus
    let hasPuzzle: Bool
    /// Weekday initial (S, M, T, W, T, F, S)
    let weekdayLetter: String
}

struct ArchiveWeek: Identifiable {
    let id: Int             // sequential index (0 = oldest, last = current week)
    let days: [ArchiveDay]  // always 7 elements, Sun–Sat
    let label: String       // e.g. "Feb 10 – 16"
}

enum PuzzleArchiveProvider {
    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let puzzleDateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "MM/dd/yyyy"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f
    }()

    private static let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    /// Builds weeks of `ArchiveDay` for the last ~5 weeks (enough to cover 30 days),
    /// organized by calendar week (Sunday–Saturday).
    static func archiveWeeks(for gameType: GameType) -> [ArchiveWeek] {
        let availableKeys: Set<String>
        switch gameType {
        case .diagone:     availableKeys = GameEngine.availableDateKeys()
        case .rhymeAGrams: availableKeys = RhymeAGramsPuzzleLibrary.availableDateKeys()
        case .tumblePuns:  availableKeys = TumblePunsPuzzleLibrary.availableDateKeys()
        }

        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday

        let today = Date()

        // Find the start of the current week (Sunday)
        let todayWeekday = calendar.component(.weekday, from: today) // 1=Sun
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -(todayWeekday - 1), to: today) else {
            return []
        }

        var weeks: [ArchiveWeek] = []
        let numberOfWeeks = 5

        let labelFormatter = DateFormatter()
        labelFormatter.calendar = calendar
        labelFormatter.locale = Locale.current
        labelFormatter.dateFormat = "MMM d"

        // Build oldest week first → newest last so the layout is chronological left-to-right
        for i in 0..<numberOfWeeks {
            let weeksAgo = numberOfWeeks - 1 - i  // 4, 3, 2, 1, 0
            guard let weekStart = calendar.date(byAdding: .day, value: -weeksAgo * 7, to: currentWeekStart) else { continue }

            var days: [ArchiveDay] = []
            for dayIndex in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayIndex, to: weekStart) else { continue }

                let isoKey = dateKeyFormatter.string(from: date)
                let puzzleKey = puzzleDateKeyFormatter.string(from: date)
                let dayOfMonth = calendar.component(.day, from: date)
                let isToday = calendar.isDateInToday(date)
                let isFirstOfMonth = dayOfMonth == 1
                let hasPuzzle = availableKeys.contains(puzzleKey)
                let isFuture = date > today

                let status: StreakManager.PuzzleStatus
                if hasPuzzle && !isFuture {
                    status = StreakManager.puzzleStatus(game: gameType, day: isoKey)
                } else {
                    status = .notStarted
                }

                days.append(ArchiveDay(
                    id: isoKey,
                    date: date,
                    dayOfMonth: dayOfMonth,
                    isToday: isToday,
                    isFirstOfMonth: isFirstOfMonth,
                    monthAbbreviation: monthFormatter.string(from: date),
                    status: status,
                    hasPuzzle: hasPuzzle && !isFuture,
                    weekdayLetter: weekdaySymbols[dayIndex]
                ))
            }

            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { continue }
            let label = "\(labelFormatter.string(from: weekStart)) – \(labelFormatter.string(from: weekEnd))"

            weeks.append(ArchiveWeek(
                id: i,
                days: days,
                label: label
            ))
        }

        return weeks
    }
}
