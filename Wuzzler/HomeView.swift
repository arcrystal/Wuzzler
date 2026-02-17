import SwiftUI

struct HomeView: View {
    let onGameSelected: (GameType, Date) -> Void
    @State private var showMenu = false
    @State private var progress = StreakManager.todayProgress()
    @State private var streakInfo = StreakManager.streakInfo()
    @State private var showDailySweep = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button { showMenu = true } label: {
                        Image(systemName: "gearshape")
                            .font(.title3.weight(.medium))
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Menu")
                    Spacer()
                    Text("Wuzzler")
                        .font(.largeTitle.weight(.bold))
                    Spacer()
                    Color.clear
                        .frame(width: 28, height: 28)
                }
                .padding(.top, 40)

                // Greeting + Streak Banner
                streakBanner

                // Daily Progress Ring
                dailyProgressSection

                // Game Cards
                ForEach(GameType.allCases) { game in
                    GameCardWithArchive(gameType: game, progress: progress, onTap: {
                        onGameSelected(game, Date())
                    }, onArchiveDateSelected: { date in
                        onGameSelected(game, date)
                    })
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(Color(UIColor.systemGray6))
        .sheet(isPresented: $showMenu) {
            MenuView()
        }
        .onAppear {
            refreshProgress()
        }
        .overlay {
            if showDailySweep {
                DailySweepCelebration {
                    showDailySweep = false
                }
            }
        }
    }

    private func refreshProgress() {
        let newProgress = StreakManager.todayProgress()
        let wasAllComplete = progress.allComplete
        progress = newProgress
        streakInfo = StreakManager.streakInfo()
        // Trigger Daily Sweep celebration if just completed all 3
        if newProgress.allComplete && !wasAllComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showDailySweep = true
            }
        }
    }

    // MARK: - Streak Banner
    private var streakBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(StreakManager.greeting)
                    .font(.headline)
                    .foregroundColor(.primary)

                if progress.allComplete {
                    Text("All puzzles complete!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    let remaining = 3 - progress.completedCount
                    Text("\(remaining) puzzle\(remaining == 1 ? "" : "s") remaining today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Streak flame
            if streakInfo.combinedStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    Text("\(streakInfo.combinedStreak)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("\(streakInfo.combinedStreak) day streak")
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Daily Progress Section
    private var dailyProgressSection: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: CGFloat(progress.completedCount) / 3.0)
                    .stroke(
                        progress.allComplete ? Color.orange : Color.accentColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: progress.completedCount)

                Text("\(progress.completedCount)/3")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(width: 44, height: 44)

            // Per-game status dots
            VStack(alignment: .leading, spacing: 6) {
                progressDot(game: .diagone, done: progress.diagoneCompleted)
                progressDot(game: .rhymeAGrams, done: progress.rhymeAGramsCompleted)
                progressDot(game: .tumblePuns, done: progress.tumblePunsCompleted)
            }

            Spacer()

            // Per-game streaks (compact)
            if streakInfo.diagoneStreak > 0 || streakInfo.rhymeAGramsStreak > 0 || streakInfo.tumblePunsStreak > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    miniStreak(game: .diagone, count: streakInfo.diagoneStreak)
                    miniStreak(game: .rhymeAGrams, count: streakInfo.rhymeAGramsStreak)
                    miniStreak(game: .tumblePuns, count: streakInfo.tumblePunsStreak)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.systemBackground))
        )
        .shadow(radius: 1, y: 1)
    }

    private func progressDot(game: GameType, done: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(done ? game.accentColor : Color.gray.opacity(0.2))
                .frame(width: 8, height: 8)
            Text(game.displayName)
                .font(.caption.weight(done ? .semibold : .regular))
                .foregroundColor(done ? .primary : .secondary)
        }
    }

    private func miniStreak(game: GameType, count: Int) -> some View {
        Group {
            if count > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                        .foregroundColor(game.accentColor)
                    Text("\(count)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundColor(game.accentColor)
                }
            } else {
                Color.clear.frame(height: 12)
            }
        }
    }
}

// MARK: - Game Card

fileprivate struct GameCard: View {
    let gameType: GameType
    let progress: StreakManager.DailyProgress
    let onTap: () -> Void

    private var isTodayCompleted: Bool {
        switch gameType {
        case .diagone: return progress.diagoneCompleted
        case .rhymeAGrams: return progress.rhymeAGramsCompleted
        case .tumblePuns: return progress.tumblePunsCompleted
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                GameIconView(gameType: gameType)
                    .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(gameType.displayName)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.primary)

                        if isTodayCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(gameType.accentColor)
                                .font(.subheadline)
                        }
                    }

                    Text(gameType.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(gameType.displayName)\(isTodayCompleted ? ", completed" : "")")
        .accessibilityHint(gameType.description)
    }
}

// MARK: - Game Card + Archive Row

fileprivate struct GameCardWithArchive: View {
    let gameType: GameType
    let progress: StreakManager.DailyProgress
    let onTap: () -> Void
    let onArchiveDateSelected: (Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Game card with bottom corners unrounded
            GameCard(gameType: gameType, progress: progress, onTap: onTap)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 16, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 16
                ))

            // Archive row with top corners unrounded
            ArchiveRowView(gameType: gameType, onDateSelected: onArchiveDateSelected)
                .background(Color(UIColor.systemBackground))
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16, topTrailingRadius: 0
                ))
        }
        .shadow(radius: 2, y: 1)
    }
}

// MARK: - Daily Sweep Celebration

private struct DailySweepCelebration: View {
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.yellow)
                    .shadow(color: .orange.opacity(0.4), radius: 8)

                Text("Daily Sweep!")
                    .font(.title.weight(.bold))

                Text("You completed all three puzzles today!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    dismiss()
                } label: {
                    Text("Nice!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.orange))
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appeared)
        .onAppear {
            appeared = true
            Haptics.notify(.success)
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onDismiss() }
    }
}

// MARK: - Custom Game Icons
fileprivate struct GameIconView: View {
    let gameType: GameType

    var body: some View {
        switch gameType {
        case .diagone:
            DiagoneIconView(size: 54, color: gameType.accentColor)
        case .rhymeAGrams:
            RhymeAGramsIconView(size: 54, color: gameType.accentColor)
        case .tumblePuns:
            TumblePunsIconView(size: 54, color: gameType.accentColor)
        }
    }
}

// Diagone: 3x3 grid of filled rounded squares
struct DiagoneIconView: View {
    let size: CGFloat
    var color: Color = .diagoneAccent

    var body: some View {
        let cellSize = size * 0.26
        let gap = size * 0.07
        VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: cellSize * 0.2, style: .continuous)
                            .fill(color)
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// RhymeAGrams: filled triangle with rounded corners
struct RhymeAGramsIconView: View {
    let size: CGFloat
    var color: Color = .rhymeAGramsAccent

    var body: some View {
        RoundedTriangle(radius: size * 0.1)
            .fill(color)
            .frame(width: size, height: size)
    }
}

private struct RoundedTriangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.0
        let top = CGPoint(x: rect.midX, y: inset)
        let bottomRight = CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
        let bottomLeft = CGPoint(x: inset, y: rect.maxY - inset)

        var path = Path()
        path.move(to: CGPoint(x: (top.x + bottomLeft.x) / 2, y: (top.y + bottomLeft.y) / 2))
        path.addArc(tangent1End: top, tangent2End: bottomRight, radius: radius)
        path.addArc(tangent1End: bottomRight, tangent2End: bottomLeft, radius: radius)
        path.addArc(tangent1End: bottomLeft, tangent2End: top, radius: radius)
        path.closeSubpath()
        return path
    }
}

// TumblePuns: 3x3 grid of filled circles
struct TumblePunsIconView: View {
    let size: CGFloat
    var color: Color = .tumblePunsAccent

    var body: some View {
        let dotSize = size * 0.26
        let gap = size * 0.07
        VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(color)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}
