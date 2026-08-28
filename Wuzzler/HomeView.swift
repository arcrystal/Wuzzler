import SwiftUI

struct HomeView: View {
    let onGameSelected: (GameLaunch) -> Void

    @State private var availability: [GameType: Bool] = [:]
    @State private var statuses: [GameType: PlayCardStatus] = [:]
    @State private var showDailySweep = false
    @AppStorage("last_daily_sweep_celebrated") private var lastDailySweepCelebrated = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    playHeader

                    ForEach(GameType.allCases) { game in
                        PlayGameCard(
                            gameType: game,
                            date: PuzzleDay.today,
                            status: statuses[game] ?? .play,
                            isAvailable: availability[game] ?? false,
                            onTap: { onGameSelected(.daily(game)) }
                        )
                        .accessibilityIdentifier("play-game-card-\(game.rawValue)")
                    }
                }
                .frame(maxWidth: 700)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Color.wuzzlerCanvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityIdentifier("play-screen")
            .onAppear(perform: refresh)
            .onReceive(NotificationCenter.default.publisher(for: .puzzleContentDidRefresh)) { _ in
                refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .gameProgressDidChange)) { _ in
                refresh()
            }
            .overlay {
                if showDailySweep {
                    DailySweepCelebration { showDailySweep = false }
                }
            }
        }
    }

    private var playHeader: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                WuzzlerWordmark()
                    .frame(maxWidth: .infinity)

                HStack {
                    Spacer()

                    NavigationLink {
                        ArchiveView(onGameSelected: onGameSelected)
                    } label: {
                        Label("Archive", systemImage: "calendar")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Color.wuzzlerSurface.opacity(0.92), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("play-archive-button")
                }
            }

            VStack(spacing: 4) {
                Text("\(StreakManager.greeting).")
                    .font(.system(.title2, design: .serif, weight: .bold))
                Text("Pick a game and play.")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
        }
        .padding(.bottom, 8)
    }

    private func refresh() {
        availability = Dictionary(uniqueKeysWithValues: GameType.allCases.map { game in
            (game, PuzzleContentService.shared.hasPuzzle(for: game, on: PuzzleDay.today))
        })
        statuses = Dictionary(uniqueKeysWithValues: GameType.allCases.map { game in
            let available = PuzzleContentService.shared.hasPuzzle(for: game, on: PuzzleDay.today)
            return (game, PlayCardStatus(game: game, date: PuzzleDay.today, isAvailable: available))
        })

        let progress = StreakManager.todayProgress()
        if progress.allComplete && lastDailySweepCelebrated != Self.todayKey {
            lastDailySweepCelebrated = Self.todayKey
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showDailySweep = true
            }
        }
    }

    private static var todayKey: String {
        PuzzleDay.storageKey(for: Date())
    }
}

private enum PlayCardStatus: Equatable {
    case play
    case inProgress
    case completed(TimeInterval)
    case comingSoon

    init(game: GameType, date: Date, isAvailable: Bool) {
        guard isAvailable else {
            self = .comingSoon
            return
        }
        switch StreakManager.puzzleStatus(game: game, day: PuzzleDay.storageKey(for: date)) {
        case .notStarted:
            self = .play
        case .inProgress:
            self = .inProgress
        case .completed(let time):
            self = .completed(time)
        }
    }

    var title: String {
        switch self {
        case .play: return "Play"
        case .inProgress: return "In Progress"
        case .completed(let time): return "Completed · \(Self.format(time))"
        case .comingSoon: return "Coming Soon"
        }
    }

    var symbol: String {
        switch self {
        case .play: return "play.fill"
        case .inProgress: return "arrow.right"
        case .completed: return "checkmark"
        case .comingSoon: return "lock.fill"
        }
    }

    private static func format(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct PlayGameCard: View {
    let gameType: GameType
    let date: Date
    let status: PlayCardStatus
    let isAvailable: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(gameType.displayName)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .lineLimit(2)

                    Text(gameType.description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.wuzzlerCardText.opacity(0.76))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Text(Self.cardDateFormatter.string(from: date))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))

                    Label(status.title, systemImage: status.symbol)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(Color.wuzzlerCardText.opacity(0.12), in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                GameCardArtwork(gameType: gameType)
                    .frame(width: 86, height: 96)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.wuzzlerCardText)
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
            .background(gameType.cardColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PlayCardButtonStyle())
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.62)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(gameType.displayName), \(status.title), \(Self.cardDateFormatter.string(from: date))")
        .accessibilityHint(isAvailable ? gameType.description : "This puzzle is not available yet")
    }

    private static let cardDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = PuzzleDay.calendar
        formatter.locale = Locale.current
        formatter.timeZone = PuzzleDay.timeZone
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
}

private struct PlayCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.06 : 0.13), radius: configuration.isPressed ? 3 : 10, y: configuration.isPressed ? 2 : 6)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct WuzzlerWordmark: View {
    private let letters = Array("WUZZLER").map(String.init)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                Text(letter)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(width: 29, height: 31)
                    .background(tileColor(at: index), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1.2 : 1.2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wuzzler")
    }

    private func tileColor(at index: Int) -> Color {
        switch index % 3 {
        case 0: return .diagoneAccent
        case 1: return .rhymeAGramsAccent
        default: return .tumblePunsAccent
        }
    }
}

private struct GameCardArtwork: View {
    let gameType: GameType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.wuzzlerCardText.opacity(0.14))
                .rotationEffect(.degrees(5))

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.wuzzlerSurface.opacity(0.9))
                .rotationEffect(.degrees(-3))
                .padding(7)

            switch gameType {
            case .diagone:
                DiagoneIconView(size: 54, color: .diagoneAccent)
            case .rhymeAGrams:
                RhymeAGramsIconView(size: 54, color: .rhymeAGramsAccent)
            case .tumblePuns:
                TumblePunsIconView(size: 54, color: .tumblePunsAccent)
            }
        }
    }
}

private struct DailySweepCelebration: View {
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 20) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.yellow)

                Text("Daily Sweep!")
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text("You completed all three puzzles today!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Nice!", action: dismiss)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .frame(minHeight: 44)
                    .background(Color.orange, in: Capsule())
            }
            .padding(32)
            .background(Color.wuzzlerSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 20)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: onDismiss)
    }
}

// MARK: - Reusable Game Artwork

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
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        var path = Path()
        path.move(to: CGPoint(x: (top.x + bottomLeft.x) / 2, y: (top.y + bottomLeft.y) / 2))
        path.addArc(tangent1End: top, tangent2End: bottomRight, radius: radius)
        path.addArc(tangent1End: bottomRight, tangent2End: bottomLeft, radius: radius)
        path.addArc(tangent1End: bottomLeft, tangent2End: top, radius: radius)
        path.closeSubpath()
        return path
    }
}

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
