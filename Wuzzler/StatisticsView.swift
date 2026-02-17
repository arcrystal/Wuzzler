import SwiftUI

struct StatisticsView: View {
    @State private var selectedGame: GameType = .diagone
    @State private var showCombined = false

    var body: some View {
        VStack(spacing: 0) {
            // Game picker + combined toggle
            VStack(spacing: 8) {
                Picker("Game", selection: $selectedGame) {
                    ForEach(GameType.allCases) { game in
                        Text(game.displayName).tag(game)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(showCombined)
                .opacity(showCombined ? 0.4 : 1)

                Toggle("Combined Stats", isOn: $showCombined)
                    .font(.subheadline)
                    .padding(.horizontal, 4)
            }
            .padding()

            ScrollView {
                if showCombined {
                    combinedStatsContent
                } else {
                    gameStatsContent(for: selectedGame)
                }
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Per-Game Stats

    @ViewBuilder
    private func gameStatsContent(for game: GameType) -> some View {
        let stats = Self.computeStats(for: game)
        let entries = Self.loadEntries(for: game)

        VStack(spacing: 24) {
            // Primary stats grid
            statsGrid(stats: stats)

            if stats.gamesWon > 0 {
                Divider().padding(.horizontal)

                // Time stats
                HStack(spacing: 0) {
                    statColumn("Best Time", value: formatTime(stats.bestTime))
                    statColumn("Avg Time", value: formatTime(stats.averageTime))
                }

                // Personal best indicator
                if stats.gamesWon > 1 {
                    let todayIsPB = StreakManager.isPersonalBest(game: game, time: stats.bestTime)
                    if todayIsPB {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("New personal best today!")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            Capsule().fill(.yellow.opacity(0.15))
                        )
                    }
                }

                Divider().padding(.horizontal)

                // Time sparkline
                if entries.filter({ $0.meta.finished && $0.meta.finishTime > 0 }).count >= 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Solve Times")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal)

                        SparklineView(
                            values: entries
                                .filter { $0.meta.finished && $0.meta.finishTime > 0 }
                                .suffix(30)
                                .map { $0.meta.finishTime },
                            color: game.accentColor
                        )
                        .frame(height: 60)
                        .padding(.horizontal)
                    }
                }

                Divider().padding(.horizontal)

                // Calendar heat map
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal)

                    CalendarHeatMap(
                        completedDates: Set(entries.filter { $0.meta.finished }.map { $0.date }),
                        startedDates: Set(entries.filter { $0.meta.started }.map { $0.date }),
                        accentColor: game.accentColor
                    )
                    .padding(.horizontal)
                }
            }

            if stats.gamesPlayed == 0 {
                emptyState
            }

            Spacer(minLength: 40)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Combined Stats

    private var combinedStatsContent: some View {
        let streakInfo = StreakManager.streakInfo()
        let allEntries = Self.loadAllGameEntries()

        return VStack(spacing: 24) {
            // Combined streak info
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    statColumn("Current\nStreak", value: "\(streakInfo.combinedStreak)")
                    statColumn("Best\nStreak", value: "\(streakInfo.bestCombinedStreak)")
                }

                // Per-game breakdown
                HStack(spacing: 0) {
                    ForEach(GameType.allCases) { game in
                        let s = Self.computeStats(for: game)
                        VStack(spacing: 4) {
                            Circle()
                                .fill(game.accentColor)
                                .frame(width: 10, height: 10)
                            Text("\(s.gamesWon)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text(game.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            // Daily sweep count
            let sweepCount = Self.dailySweepCount()
            if sweepCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("\(sweepCount) Daily Sweep\(sweepCount == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    Capsule().fill(.yellow.opacity(0.12))
                )
            }

            Divider().padding(.horizontal)

            // Combined calendar heat map
            VStack(alignment: .leading, spacing: 8) {
                Text("Activity (All Games)")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)

                CalendarHeatMap(
                    completedDates: allEntries.completedDates,
                    startedDates: allEntries.startedDates,
                    accentColor: .orange
                )
                .padding(.horizontal)
            }

            Spacer(minLength: 40)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Shared Components

    private func statsGrid(stats: GameStats) -> some View {
        HStack(spacing: 0) {
            statColumn("Played", value: "\(stats.gamesPlayed)")
            statColumn("Win %", value: stats.gamesPlayed > 0 ? "\(Int(stats.winRate * 100))" : "-")
            statColumn("Current\nStreak", value: "\(stats.currentStreak)")
            statColumn("Max\nStreak", value: "\(stats.maxStreak)")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "puzzlepiece")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Play your first game to see stats!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 32)
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

    fileprivate struct DailyMeta: Codable {
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

    fileprivate struct DayEntry {
        let date: String
        let meta: DailyMeta
    }

    private static func loadEntries(for game: GameType) -> [DayEntry] {
        let prefix: String
        switch game {
        case .diagone: prefix = "diagone"
        case .rhymeAGrams: prefix = "rhymeagrams"
        case .tumblePuns: prefix = "tumblepuns"
        }
        let metaPrefix = "\(prefix)_meta_"
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        var entries: [DayEntry] = []

        for key in allKeys where key.hasPrefix(metaPrefix) {
            let dateStr = String(key.dropFirst(metaPrefix.count))
            guard let data = UserDefaults.standard.data(forKey: key),
                  let meta = try? JSONDecoder().decode(DailyMeta.self, from: data) else { continue }
            entries.append(DayEntry(date: dateStr, meta: meta))
        }

        entries.sort { $0.date < $1.date }
        return entries
    }

    private static func computeStats(for game: GameType) -> GameStats {
        let entries = loadEntries(for: game)
        let played = entries.filter { $0.meta.started }.count
        let won = entries.filter { $0.meta.finished }.count

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

    private static func loadAllGameEntries() -> (completedDates: Set<String>, startedDates: Set<String>) {
        var completed = Set<String>()
        var started = Set<String>()
        for game in GameType.allCases {
            let entries = loadEntries(for: game)
            for e in entries {
                if e.meta.finished { completed.insert(e.date) }
                if e.meta.started { started.insert(e.date) }
            }
        }
        return (completed, started)
    }

    private static func dailySweepCount() -> Int {
        let prefixes = ["diagone_meta_", "rhymeagrams_meta_", "tumblepuns_meta_"]
        var allDates = Set<String>()
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys {
            for p in prefixes where key.hasPrefix(p) {
                allDates.insert(String(key.dropFirst(p.count)))
            }
        }

        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"

        var count = 0
        for date in allDates {
            let allDone = ["diagone", "rhymeagrams", "tumblepuns"].allSatisfy { prefix in
                let key = "\(prefix)_meta_\(date)"
                guard let data = UserDefaults.standard.data(forKey: key),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let finished = json["finished"] as? Bool else { return false }
                return finished
            }
            if allDone { count += 1 }
        }
        return count
    }
}

// MARK: - Sparkline View

struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            guard values.count >= 2 else { return AnyView(EmptyView()) }
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 1
            let range = max(maxVal - minVal, 1)
            let stepX = width / CGFloat(values.count - 1)

            return AnyView(
                ZStack {
                    // Gradient fill
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        for (i, val) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = height - (CGFloat(val - minVal) / CGFloat(range)) * height * 0.85 - height * 0.05
                            if i == 0 {
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: CGFloat(values.count - 1) * stepX, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { path in
                        for (i, val) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = height - (CGFloat(val - minVal) / CGFloat(range)) * height * 0.85 - height * 0.05
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Dot on latest value
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(
                            x: CGFloat(values.count - 1) * stepX,
                            y: height - (CGFloat(values.last! - minVal) / CGFloat(range)) * height * 0.85 - height * 0.05
                        )
                }
            )
        }
    }
}

// MARK: - Calendar Heat Map

struct CalendarHeatMap: View {
    let completedDates: Set<String>
    let startedDates: Set<String>
    let accentColor: Color

    // Show last 8 weeks (56 days)
    private let weeksToShow = 8
    private let daySize: CGFloat = 14
    private let daySpacing: CGFloat = 3

    private var days: [String] {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"

        var result: [String] = []
        let totalDays = weeksToShow * 7
        for i in stride(from: totalDays - 1, through: 0, by: -1) {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            result.append(fmt.string(from: date))
        }
        return result
    }

    private let dayLabels = ["M", "", "W", "", "F", "", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: daySpacing) {
                // Day labels column
                VStack(spacing: daySpacing) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(dayLabels[i])
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(width: daySize, height: daySize)
                    }
                }

                // Week columns
                let allDays = days
                ForEach(0..<weeksToShow, id: \.self) { week in
                    VStack(spacing: daySpacing) {
                        ForEach(0..<7, id: \.self) { day in
                            let index = week * 7 + day
                            if index < allDays.count {
                                let dateStr = allDays[index]
                                dayCell(dateStr: dateStr)
                            } else {
                                Color.clear.frame(width: daySize, height: daySize)
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Spacer()
                Text("Less")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor.opacity(0.3))
                    .frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor.opacity(0.7))
                    .frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 10, height: 10)
                Text("More")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func dayCell(dateStr: String) -> some View {
        let isCompleted = completedDates.contains(dateStr)
        let isStarted = startedDates.contains(dateStr)

        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(cellColor(completed: isCompleted, started: isStarted))
            .frame(width: daySize, height: daySize)
    }

    private func cellColor(completed: Bool, started: Bool) -> Color {
        if completed {
            return accentColor
        } else if started {
            return accentColor.opacity(0.3)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
}
