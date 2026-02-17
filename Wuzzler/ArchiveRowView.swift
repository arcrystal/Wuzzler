import SwiftUI

struct ArchiveRowView: View {
    let gameType: GameType
    let onDateSelected: (Date) -> Void

    @State private var weeks: [ArchiveWeek] = []
    @State private var visibleWeekId: Int?

    var body: some View {
        VStack(spacing: 3) {
            weekLabel
            pagedStrip
        }
        .padding(.vertical, 6)
        .onAppear {
            weeks = PuzzleArchiveProvider.archiveWeeks(for: gameType)
            visibleWeekId = weeks.last?.id
        }
    }

    // MARK: - Week Label

    private var weekLabel: some View {
        Text(weeks.first { $0.id == visibleWeekId }?.label ?? "")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Paged Strip

    private var pagedStrip: some View {
        GeometryReader { geo in
            let tileWidth = (geo.size.width - 32 - 36) / 7
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(weeks) { week in
                        weekPage(week: week, tileWidth: tileWidth)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleWeekId)
            .defaultScrollAnchor(.trailing)
        }
        .frame(height: 52)
    }

    private func weekPage(week: ArchiveWeek, tileWidth: CGFloat) -> some View {
        HStack(spacing: 6) {
            ForEach(week.days) { day in
                ArchiveDateCell(
                    day: day,
                    accentColor: gameType.accentColor,
                    tileSize: tileWidth
                ) {
                    onDateSelected(day.date)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Archive Date Cell

private struct ArchiveDateCell: View {
    let day: ArchiveDay
    let accentColor: Color
    let tileSize: CGFloat
    let onTap: () -> Void

    @State private var breathingOpacity: Double = 1.0

    var body: some View {
        Button {
            guard day.hasPuzzle else { return }
            onTap()
        } label: {
            VStack(spacing: 1) {
                tileBody
                timeLabel
            }
        }
        .buttonStyle(ArchiveCellButtonStyle())
        .disabled(!day.hasPuzzle)
        .onAppear { startBreathingIfToday() }
    }

    // MARK: - Tile Body

    private var tileBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fillColor)
                .frame(width: tileSize, height: tileSize)

            if day.isToday {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(accentColor, lineWidth: 2)
                    .frame(width: tileSize, height: tileSize)
                    .opacity(breathingOpacity)
            }

            cellContent
        }
    }

    @ViewBuilder
    private var timeLabel: some View {
        if case .completed(let time) = day.status {
            Text(formatTime(time))
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(accentColor)
                .lineLimit(1)
        } else {
            Color.clear.frame(height: 9)
        }
    }

    // MARK: - Cell Content

    @ViewBuilder
    private var cellContent: some View {
        if !day.hasPuzzle {
            Text("\(day.dayOfMonth)")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(Color(UIColor.systemGray4))
        } else {
            switch day.status {
            case .completed:
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            case .inProgress:
                Circle()
                    .fill(accentColor)
                    .frame(width: 5, height: 5)
            case .notStarted:
                Text("\(day.dayOfMonth)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var fillColor: Color {
        if !day.hasPuzzle { return Color(UIColor.systemGray6) }
        switch day.status {
        case .completed:  return accentColor
        case .inProgress: return accentColor.opacity(0.25)
        case .notStarted: return Color(UIColor.systemGray5)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startBreathingIfToday() {
        guard day.isToday else { return }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            breathingOpacity = 0.5
        }
    }
}

// MARK: - Button Style

private struct ArchiveCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
