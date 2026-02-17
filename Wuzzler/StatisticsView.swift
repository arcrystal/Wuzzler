import SwiftUI

struct StatisticsView: View {
    @State private var selectedGame: GameType = .diagone

    var body: some View {
        VStack(spacing: 0) {
            Picker("Game", selection: $selectedGame) {
                ForEach(GameType.allCases) { game in
                    Text(game.displayName).tag(game)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            let stats = Self.computeStats(for: selectedGame)

            ScrollView {
                VStack(spacing: 28) {
                    // Main stats row
                    HStack(spacing: 0) {
                        statColumn("Played", value: "\(stats.gamesPlayed)")
                        statColumn("Win %", value: stats.gamesPlayed > 0 ? "\(Int(stats.winRate * 100))" : "-")
                        statColumn("Current\nStreak", value: "\(stats.currentStreak)")
                        statColumn("Max\nStreak", value: "\(stats.maxStreak)")
                    }

                    if stats.gamesWon > 0 {
                        Divider().padding(.horizontal)

                        HStack(spacing: 0) {
                            statColumn("Best Time", value: formatTime(stats.bestTime))
                            statColumn("Avg Time", value: formatTime(stats.averageTime))
                        }
                    }

                    if stats.gamesPlayed == 0 {
                        Text("Play your first game to see stats!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                    }
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statColumn(_ label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Stats Computation

    private struct DailyMeta: Codable {
        var started: Bool
        var finished: Bool
        var elapsedTime: TimeInterval
        var finishTime: TimeInterval
        var lastUpdated: Date
    }

    struct GameStats {
        let gamesPlayed: Int
        let gamesWon: Int
        var winRate: Double { gamesPlayed > 0 ? Double(gamesWon) / Double(gamesPlayed) : 0 }
        let currentStreak: Int
        let maxStreak: Int
        let averageTime: TimeInterval
        let bestTime: TimeInterval
    }

    static func computeStats(for game: GameType) -> GameStats {
        let prefix: String
        switch game {
        case .diagone: prefix = "diagone"
        case .rhymeAGrams: prefix = "rhymeagrams"
        case .tumblePuns: prefix = "tumblepuns"
        }
        let metaPrefix = "\(prefix)_meta_"

        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        var entries: [(date: String, meta: DailyMeta)] = []

        for key in allKeys where key.hasPrefix(metaPrefix) {
            let dateStr = String(key.dropFirst(metaPrefix.count))
            guard let data = UserDefaults.standard.data(forKey: key),
                  let meta = try? JSONDecoder().decode(DailyMeta.self, from: data) else { continue }
            entries.append((dateStr, meta))
        }

        entries.sort { $0.date < $1.date }

        let played = entries.filter { $0.meta.started }.count
        let won = entries.filter { $0.meta.finished }.count

        // Current streak: walk backwards from today
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"

        let wonDates = Set(entries.filter { $0.meta.finished }.map { $0.date })

        var currentStreak = 0
        var checkDate = Date()
        while true {
            let ds = fmt.string(from: checkDate)
            if wonDates.contains(ds) {
                currentStreak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        // Max streak: walk through all calendar days that have entries
        var maxStreak = 0
        var streak = 0
        if let firstDate = entries.first.flatMap({ fmt.date(from: $0.date) }),
           let lastDate = entries.last.flatMap({ fmt.date(from: $0.date) }) {
            var day = firstDate
            while day <= lastDate {
                let ds = fmt.string(from: day)
                if wonDates.contains(ds) {
                    streak += 1
                    maxStreak = max(maxStreak, streak)
                } else {
                    streak = 0
                }
                day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
            }
        }
        maxStreak = max(maxStreak, currentStreak)

        // Time stats
        let winTimes = entries.filter { $0.meta.finished && $0.meta.finishTime > 0 }.map { $0.meta.finishTime }
        let avgTime = winTimes.isEmpty ? 0 : winTimes.reduce(0, +) / Double(winTimes.count)
        let bestTime = winTimes.min() ?? 0

        return GameStats(
            gamesPlayed: played,
            gamesWon: won,
            currentStreak: currentStreak,
            maxStreak: maxStreak,
            averageTime: avgTime,
            bestTime: bestTime
        )
    }
}
