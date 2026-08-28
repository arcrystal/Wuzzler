import Foundation

enum PuzzleDay {
    static let timeZone = TimeZone(secondsFromGMT: 0)!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        calendar.firstWeekday = 1
        return calendar
    }

    static var today: Date {
        startOfDay(for: Date())
    }

    static func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func isToday(_ date: Date) -> Bool {
        storageKey(for: date) == storageKey(for: Date())
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: startOfDay(for: date)) ?? startOfDay(for: date)
    }

    static func storageKey(for date: Date) -> String {
        formatter("yyyy-MM-dd").string(from: startOfDay(for: date))
    }

    static func puzzleKey(for date: Date) -> String {
        formatter("MM/dd/yyyy").string(from: startOfDay(for: date))
    }

    static func displayDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.timeZone = timeZone
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: startOfDay(for: date))
    }

    static func puzzleNumber(for date: Date) -> String {
        let raw = formatter("yyyyMMdd").string(from: startOfDay(for: date))
        let value = Int(raw) ?? 0
        return String(format: "#%04d", value % 5000)
    }

    static func date(fromStorageKey key: String) -> Date? {
        formatter("yyyy-MM-dd").date(from: key)
    }

    static func date(fromPuzzleKey key: String) -> Date? {
        formatter("MM/dd/yyyy").date(from: key)
    }

    static func leaderboardContext(for date: Date) -> Int {
        Int(storageKey(for: date).replacingOccurrences(of: "-", with: "")) ?? 0
    }

    static func storagePrefix(for game: GameType) -> String {
        switch game {
        case .diagone: return "diagone"
        case .rhymeAGrams: return "rhymeagrams"
        case .tumblePuns: return "tumblepuns"
        }
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}
