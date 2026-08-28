import SwiftUI

struct GameCoordinatorView: View {
    let gameType: GameType
    let puzzleDate: Date
    let countsTowardStats: Bool
    let onBackToHome: () -> Void

    var body: some View {
        Group {
            if PuzzleContentService.shared.hasPuzzle(for: gameType, on: puzzleDate) {
                switch gameType {
                case .diagone:
                    DiagoneCoordinatorView(puzzleDate: puzzleDate, countsTowardStats: countsTowardStats, onBackToHome: onBackToHome)
                case .rhymeAGrams:
                    RhymeAGramsCoordinatorView(puzzleDate: puzzleDate, countsTowardStats: countsTowardStats, onBackToHome: onBackToHome)
                case .tumblePuns:
                    TumblePunsCoordinatorView(puzzleDate: puzzleDate, countsTowardStats: countsTowardStats, onBackToHome: onBackToHome)
                }
            } else {
                MissingPuzzleView(gameType: gameType, date: puzzleDate, onBackToHome: onBackToHome)
            }
        }
        .environment(\.gameAccent, gameType.accentColor)
    }
}

private struct MissingPuzzleView: View {
    let gameType: GameType
    let date: Date
    let onBackToHome: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(gameType.accentColor)

            Text("Puzzle coming soon")
                .font(.title2.weight(.bold))

            Text("\(gameType.displayName) is not available for \(PuzzleDay.displayDate(date)) yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button {
                onBackToHome()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(gameType.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - Diagone Coordinator
private struct DiagoneCoordinatorView: View {
    enum Route { case loading, playing }

    let puzzleDate: Date
    let countsTowardStats: Bool
    let onBackToHome: () -> Void
    @State private var route: Route = .loading
    @StateObject private var viewModel: GameViewModel

    init(puzzleDate: Date, countsTowardStats: Bool, onBackToHome: @escaping () -> Void) {
        self.puzzleDate = puzzleDate
        self.countsTowardStats = countsTowardStats
        self.onBackToHome = onBackToHome
        _viewModel = StateObject(wrappedValue: GameViewModel(puzzleDate: puzzleDate, countsTowardStats: countsTowardStats))
    }

    var body: some View {
        Group {
            switch route {
            case .loading:
                DiagoneLoadingView(
                    date: puzzleDate,
                    onStart: {
                        route = .playing
                    },
                    onBack: onBackToHome
                )
            case .playing:
                GameFlowView(
                    viewModel: viewModel,
                    gameName: "Diagone",
                    gameDescription: "Drag and drop diagonals to spell six horizontal words",
                    iconView: DiagoneIconView(size: 80),
                    tutorialSteps: [
                        TutorialStep(icon: "square.grid.3x3", title: "Welcome to Diagone", description: "Place diagonal word chips onto a 6\u{00d7}6 board to spell six horizontal words."),
                        TutorialStep(icon: "hand.draw", title: "Drag & Drop", description: "Drag chips from the tray onto the board. Each chip fills a diagonal of matching length."),
                        TutorialStep(icon: "arrow.uturn.backward", title: "Rearrange Freely", description: "Drag a placed chip to a different diagonal, or drag it off the board to remove it."),
                        TutorialStep(icon: "character.textbox", title: "Complete the Diagonal", description: "Once all chips are placed, type letters into the highlighted main diagonal to finish the puzzle."),
                    ],
                    confettiColors: [.diagoneAccent, .yellow, .orange, .white],
                    shareCardBuilder: { vm in
                        let streak = vm.countsTowardStats ? StreakManager.streakInfo().diagoneStreak : 0
                        return ShareCardBuilder.diagoneCard(time: vm.finishTime, streakCount: streak)
                    },
                    gameContent: { onPause in
                        DiagoneGameView(viewModel: viewModel, onPause: onPause)
                    },
                    onBackToHome: onBackToHome,
                    onExitHub: {
                        if viewModel.finished { viewModel.showMainInput = false }
                    }
                )
            }
        }
        .onAppear {
            if viewModel.started {
                route = .playing
            }
        }
    }
}

// MARK: - RhymeAGrams Coordinator
private struct RhymeAGramsCoordinatorView: View {
    enum Route { case loading, playing }

    let puzzleDate: Date
    let countsTowardStats: Bool
    let onBackToHome: () -> Void
    @State private var route: Route = .loading
    @StateObject private var viewModel: RhymeAGramsViewModel

    init(puzzleDate: Date, countsTowardStats: Bool, onBackToHome: @escaping () -> Void) {
        self.puzzleDate = puzzleDate
        self.countsTowardStats = countsTowardStats
        self.onBackToHome = onBackToHome
        _viewModel = StateObject(wrappedValue: RhymeAGramsViewModel(puzzleDate: puzzleDate, countsTowardStats: countsTowardStats))
    }

    var body: some View {
        Group {
            switch route {
            case .loading:
                RhymeAGramsLoadingView(
                    date: puzzleDate,
                    onStart: {
                        route = .playing
                    },
                    onBack: onBackToHome
                )
            case .playing:
                GameFlowView(
                    viewModel: viewModel,
                    gameName: "RhymeAGram",
                    gameDescription: "Find four 4-letter rhyming words from a pyramid of letters",
                    iconView: RhymeAGramsIconView(size: 80),
                    tutorialSteps: [
                        TutorialStep(icon: "triangle", title: "Welcome to RhymeAGram", description: "Find four 4-letter rhyming words hidden in the pyramid of letters. All four words rhyme!"),
                        TutorialStep(icon: "hand.tap", title: "Tap to Spell", description: "Tap letters in the pyramid or use the keyboard to spell each word. Every letter is used exactly once across all four words."),
                        TutorialStep(icon: "arrow.right.arrow.left", title: "Navigate Words", description: "Tap any answer row to select it. Words auto-advance when filled. Backspace moves to the previous word if the current one is empty."),
                    ],
                    confettiColors: [.rhymeAGramsAccent, .yellow, .green, .white],
                    shareCardBuilder: { vm in
                        let streak = vm.countsTowardStats ? StreakManager.streakInfo().rhymeAGramsStreak : 0
                        return ShareCardBuilder.rhymeAGramsCard(time: vm.finishTime, streakCount: streak)
                    },
                    gameContent: { onPause in
                        RhymeAGramsGameView(viewModel: viewModel, onPause: onPause)
                    },
                    onBackToHome: onBackToHome
                )
            }
        }
        .onAppear {
            if viewModel.started {
                route = .playing
            }
        }
    }
}

// MARK: - TumblePuns Coordinator
private struct TumblePunsCoordinatorView: View {
    enum Route { case loading, playing }

    let puzzleDate: Date
    let countsTowardStats: Bool
    let onBackToHome: () -> Void
    @State private var route: Route = .loading
    @StateObject private var viewModel: TumblePunsViewModel

    init(puzzleDate: Date, countsTowardStats: Bool, onBackToHome: @escaping () -> Void) {
        self.puzzleDate = puzzleDate
        self.countsTowardStats = countsTowardStats
        self.onBackToHome = onBackToHome
        _viewModel = StateObject(wrappedValue: TumblePunsViewModel(puzzleDate: puzzleDate, countsTowardStats: countsTowardStats))
    }

    var body: some View {
        Group {
            switch route {
            case .loading:
                TumblePunsLoadingView(
                    date: puzzleDate,
                    onStart: {
                        route = .playing
                    },
                    onBack: onBackToHome
                )
            case .playing:
                GameFlowView(
                    viewModel: viewModel,
                    gameName: "TumblePun",
                    gameDescription: "Unscramble words and solve the punny clue",
                    iconView: TumblePunsIconView(size: 80),
                    tutorialSteps: [
                        TutorialStep(icon: "circle.grid.3x3", title: "Welcome to TumblePun", description: "Unscramble four jumbled words, then use the highlighted letters to solve a punny clue."),
                        TutorialStep(icon: "arrow.triangle.2.circlepath", title: "Unscramble Words", description: "Tap a word to select it, then type the correct spelling. Use the shuffle button to rearrange the scrambled letters for a fresh look."),
                        TutorialStep(icon: "paintbrush.pointed", title: "Shaded Letters", description: "Each solved word reveals its shaded letters. These special letters combine to form the final answer."),
                        TutorialStep(icon: "lightbulb", title: "Solve the Pun", description: "Complete all four words to reveal the clue, then unscramble the shaded letters to find the punny final answer."),
                    ],
                    confettiColors: [.tumblePunsAccent, .yellow, .red, .white],
                    shareCardBuilder: { vm in
                        let streak = vm.countsTowardStats ? StreakManager.streakInfo().tumblePunsStreak : 0
                        return ShareCardBuilder.tumblePunsCard(
                            wordLengths: vm.puzzle.words.map { $0.solution.count },
                            shadedIndices: vm.puzzle.words.map { $0.shadedIndices },
                            answerPattern: vm.puzzle.answerPattern,
                            time: vm.finishTime,
                            streakCount: streak
                        )
                    },
                    gameContent: { onPause in
                        TumblePunsGameView(viewModel: viewModel, onPause: onPause)
                    },
                    onBackToHome: onBackToHome
                )
            }
        }
        .onAppear {
            if viewModel.started {
                route = .playing
            }
        }
    }
}
