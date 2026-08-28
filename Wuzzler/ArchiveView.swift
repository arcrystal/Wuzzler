import SwiftUI

struct ArchiveView: View {
    let onGameSelected: (GameLaunch) -> Void

    @State private var selectedGame: GameType = .diagone
    @State private var months: [ArchiveMonth] = []
    @State private var selectedMonthID: String?

    private let weekdaySymbols = Calendar.current.veryShortStandaloneWeekdaySymbols
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                gameSelector

                if let month = selectedMonth {
                    monthCard(month)
                    archiveLegend
                } else {
                    ContentUnavailableView(
                        "No archived puzzles",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No dates are available for \(selectedGame.displayName).")
                    )
                    .frame(minHeight: 320)
                }

                practiceExplanation
            }
            .frame(maxWidth: 700)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Color.wuzzlerCanvas.ignoresSafeArea())
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reloadMonths(resetSelection: selectedMonthID == nil) }
        .onChange(of: selectedGame) { _, _ in reloadMonths(resetSelection: true) }
        .onReceive(NotificationCenter.default.publisher(for: .puzzleContentDidRefresh)) { _ in
            reloadMonths(resetSelection: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameProgressDidChange)) { _ in
            reloadMonths(resetSelection: false)
        }
        .accessibilityIdentifier("archive-screen")
    }

    private var selectedMonth: ArchiveMonth? {
        months.first { $0.id == selectedMonthID }
    }

    private var selectedMonthIndex: Int? {
        months.firstIndex { $0.id == selectedMonthID }
    }

    private var gameSelector: some View {
        HStack(spacing: 6) {
            ForEach(GameType.allCases) { game in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedGame = game
                    }
                } label: {
                    Text(game.displayName)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(selectedGame == game ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            selectedGame == game ? game.accentColor : Color.wuzzlerSurface,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedGame == game ? .isSelected : [])
                .accessibilityIdentifier("archive-game-\(game.rawValue)")
            }
        }
        .padding(5)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private func monthCard(_ month: ArchiveMonth) -> some View {
        VStack(spacing: 10) {
            HStack {
                monthButton(systemImage: "chevron.left", direction: -1)

                Text(month.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)

                monthButton(systemImage: "chevron.right", direction: 1)
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .accessibilityHidden(true)
                }

                ForEach(0..<month.leadingBlankCount, id: \.self) { _ in
                    Color.clear
                        .frame(minHeight: 44)
                        .accessibilityHidden(true)
                }

                ForEach(month.days) { day in
                    ArchiveDateCell(day: day, accentColor: selectedGame.accentColor) {
                        onGameSelected(.archive(selectedGame, date: day.date))
                    }
                    .accessibilityIdentifier("archive-date-\(day.id)")
                }
            }
        }
        .padding(12)
        .background(Color.wuzzlerSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
    }

    private func monthButton(systemImage: String, direction: Int) -> some View {
        Button {
            guard let index = selectedMonthIndex else { return }
            let newIndex = index + direction
            guard months.indices.contains(newIndex) else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMonthID = months[newIndex].id
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canMoveMonth(direction))
        .opacity(canMoveMonth(direction) ? 1 : 0.3)
        .accessibilityLabel(direction < 0 ? "Previous month" : "Next month")
    }

    private func canMoveMonth(_ direction: Int) -> Bool {
        guard let index = selectedMonthIndex else { return false }
        return months.indices.contains(index + direction)
    }

    private var archiveLegend: some View {
        Grid(horizontalSpacing: 18, verticalSpacing: 10) {
            GridRow {
                legendItem("Not started", style: .notStarted)
                legendItem("In progress", style: .inProgress)
            }
            GridRow {
                legendItem("Completed", style: .completed)
                legendItem("Unavailable", style: .unavailable)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func legendItem(_ title: String, style: ArchiveLegendStyle) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(style.fill(accent: selectedGame.accentColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(style.stroke(accent: selectedGame.accentColor), lineWidth: 1.5)
                }
                .frame(width: 18, height: 18)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var practiceExplanation: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Archive solves are practice")
                .font(.system(.headline, design: .rounded, weight: .bold))
            Text("Progress is saved, but practice never affects streaks, achievements, personal bests, or leaderboards. Today’s puzzle still counts as the daily puzzle.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.wuzzlerSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func reloadMonths(resetSelection: Bool) {
        let updated = PuzzleArchiveProvider.archiveMonths(for: selectedGame)
        let existingID = selectedMonthID
        months = updated

        if !resetSelection, let existingID, updated.contains(where: { $0.id == existingID }) {
            selectedMonthID = existingID
            return
        }

        selectedMonthID = updated.first(where: { month in
            month.days.contains(where: \.isToday)
        })?.id ?? updated.last(where: { $0.startDate <= PuzzleDay.today })?.id ?? updated.first?.id
    }
}

private enum ArchiveLegendStyle {
    case notStarted
    case inProgress
    case completed
    case unavailable

    func fill(accent: Color) -> Color {
        switch self {
        case .notStarted: return .wuzzlerSurface
        case .inProgress: return accent.opacity(0.25)
        case .completed: return accent
        case .unavailable: return Color.primary.opacity(0.06)
        }
    }

    func stroke(accent: Color) -> Color {
        switch self {
        case .notStarted: return Color.primary.opacity(0.25)
        case .inProgress, .completed: return accent
        case .unavailable: return Color.primary.opacity(0.08)
        }
    }
}

private struct ArchiveDateCell: View {
    let day: ArchiveDay
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(fillColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(strokeColor, lineWidth: day.isToday ? 2.5 : 1.25)
                    }

                cellContent
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!day.canLaunch)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(day.canLaunch ? (day.isToday ? "Opens today’s daily puzzle" : "Opens as a practice puzzle") : "Unavailable")
    }

    @ViewBuilder
    private var cellContent: some View {
        switch day.status {
        case .completed where day.canLaunch:
            VStack(spacing: 1) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                Text("\(day.dayOfMonth)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.white)
        case .inProgress where day.canLaunch:
            VStack(spacing: 3) {
                Text("\(day.dayOfMonth)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Capsule()
                    .fill(accentColor)
                    .frame(width: 15, height: 3)
            }
            .foregroundStyle(Color.primary)
        default:
            Text("\(day.dayOfMonth)")
                .font(.system(.subheadline, design: .rounded, weight: day.isToday ? .bold : .medium))
                .foregroundStyle(day.canLaunch ? Color.primary : Color.secondary.opacity(0.45))
        }
    }

    private var fillColor: Color {
        guard day.canLaunch else { return Color.primary.opacity(0.045) }
        switch day.status {
        case .completed: return accentColor
        case .inProgress: return accentColor.opacity(0.22)
        case .notStarted: return Color.clear
        }
    }

    private var strokeColor: Color {
        if day.isToday { return accentColor }
        guard day.canLaunch else { return Color.clear }
        switch day.status {
        case .completed, .inProgress: return accentColor
        case .notStarted: return Color.primary.opacity(0.18)
        }
    }

    private var accessibilityLabel: String {
        let date = PuzzleDay.displayDate(day.date, style: .long)
        guard day.canLaunch else { return "\(date), unavailable" }
        switch day.status {
        case .notStarted:
            return "\(date), not started"
        case .inProgress:
            return "\(date), in progress"
        case .completed(let time):
            let total = max(0, Int(time.rounded()))
            return "\(date), completed in \(total / 60) minutes \(total % 60) seconds"
        }
    }
}
