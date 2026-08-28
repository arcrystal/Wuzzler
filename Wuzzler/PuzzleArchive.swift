import Foundation

struct ArchiveDay: Identifiable {
    let id: String
    let date: Date
    let dayOfMonth: Int
    let isToday: Bool
    let isFuture: Bool
    let hasPuzzle: Bool
    let status: StreakManager.PuzzleStatus

    var canLaunch: Bool { hasPuzzle && !isFuture }
}

struct ArchiveMonth: Identifiable {
    let id: String
    let startDate: Date
    let title: String
    let leadingBlankCount: Int
    let days: [ArchiveDay]
}

enum PuzzleArchiveProvider {
    static func availablePuzzleKeys(for gameType: GameType) -> Set<String> {
        switch gameType {
        case .diagone:
            return GameEngine.availableDateKeys()
        case .rhymeAGrams:
            return RhymeAGramsPuzzleLibrary.availableDateKeys()
        case .tumblePuns:
            return TumblePunsPuzzleLibrary.availableDateKeys()
        }
    }

    static func archiveMonths(
        for gameType: GameType,
        today: Date = PuzzleDay.today
    ) -> [ArchiveMonth] {
        makeMonths(
            gameType: gameType,
            availablePuzzleKeys: availablePuzzleKeys(for: gameType),
            today: today
        )
    }

    /// Exposed separately so month boundaries and missing dates can be tested
    /// without coupling tests to the bundled puzzle inventory.
    static func makeMonths(
        gameType: GameType,
        availablePuzzleKeys: Set<String>,
        today: Date
    ) -> [ArchiveMonth] {
        let calendar = PuzzleDay.calendar
        let dates = availablePuzzleKeys.compactMap(PuzzleDay.date(fromPuzzleKey:)).sorted()
        guard let firstDate = dates.first, let lastDate = dates.last,
              let firstMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: firstDate)),
              let lastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastDate)) else {
            return []
        }

        let normalizedToday = PuzzleDay.startOfDay(for: today)
        var cursor = firstMonth
        var months: [ArchiveMonth] = []

        while cursor <= lastMonth {
            guard let range = calendar.range(of: .day, in: .month, for: cursor) else { break }
            let weekday = calendar.component(.weekday, from: cursor)
            let leadingBlankCount = (weekday - calendar.firstWeekday + 7) % 7

            let days = range.compactMap { dayNumber -> ArchiveDay? in
                guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: cursor) else {
                    return nil
                }
                let puzzleKey = PuzzleDay.puzzleKey(for: date)
                let hasPuzzle = availablePuzzleKeys.contains(puzzleKey)
                let isFuture = date > normalizedToday
                let status: StreakManager.PuzzleStatus = hasPuzzle && !isFuture
                    ? StreakManager.puzzleStatus(game: gameType, day: PuzzleDay.storageKey(for: date))
                    : .notStarted

                return ArchiveDay(
                    id: PuzzleDay.storageKey(for: date),
                    date: date,
                    dayOfMonth: dayNumber,
                    isToday: PuzzleDay.storageKey(for: date) == PuzzleDay.storageKey(for: normalizedToday),
                    isFuture: isFuture,
                    hasPuzzle: hasPuzzle,
                    status: status
                )
            }

            months.append(
                ArchiveMonth(
                    id: monthIDFormatter.string(from: cursor),
                    startDate: cursor,
                    title: monthTitleFormatter.string(from: cursor),
                    leadingBlankCount: leadingBlankCount,
                    days: days
                )
            )

            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }

        return months
    }

    private static let monthIDFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = PuzzleDay.calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = PuzzleDay.timeZone
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = PuzzleDay.calendar
        formatter.locale = Locale.current
        formatter.timeZone = PuzzleDay.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}
