import SwiftUI

struct GameCoordinatorView: View {
    let gameType: GameType
    let onBackToHome: () -> Void

    var body: some View {
        Group {
            switch gameType {
            case .diagone:
                DiagoneCoordinatorView(onBackToHome: onBackToHome)
            case .rhymeAGrams:
                RhymeAGramsCoordinatorView(onBackToHome: onBackToHome)
            case .tumblePuns:
                TumblePunsCoordinatorView(onBackToHome: onBackToHome)
            }
        }
        .environment(\.gameAccent, gameType.accentColor)
    }
}

// MARK: - Diagone Coordinator
private struct DiagoneCoordinatorView: View {
    enum Route { case loading, playing }

    let onBackToHome: () -> Void
    @State private var route: Route = .loading
    @StateObject private var viewModel = GameViewModel(engine: GameEngine(puzzleDate: Date()))

    var body: some View {
        Group {
            switch route {
            case .loading:
                DiagoneLoadingView(
                    date: Date(),
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
                        let streak = StreakManager.streakInfo().diagoneStreak
                        return ShareCardBuilder.diagoneCard(time: vm.finishTime, streakCount: streak)
                    },
                    gameContent: { onPause in
                        DiagoneGameView(viewModel: viewModel, onPause: onPause)
                    },
                    onBackToHome: onBackToHome,
                    onExitHub: {
                        if viewModel.finished { viewModel.showMainInput = false }
                    },
                    hubTransitionDelay: 4.0  // Diagone has row highlight animation after win
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

    let onBackToHome: () -> Void
    @State private var route: Route = .loading
    @StateObject private var viewModel = RhymeAGramsViewModel()

    var body: some View {
        Group {
            switch route {
            case .loading:
                RhymeAGramsLoadingView(
                    date: Date(),
                    onStart: {
                        route = .playing
                    },
                    onBack: onBackToHome
                )
            case .playing:
                GameFlowView(
                    viewModel: viewModel,
                    gameName: "RhymeAGrams",
                    gameDescription: "Find four 4-letter rhyming words from a pyramid of letters",
                    iconView: RhymeAGramsIconView(size: 80),
                    tutorialSteps: [
                        TutorialStep(icon: "triangle", title: "Welcome to RhymeAGrams", description: "Find four 4-letter rhyming words hidden in the pyramid of letters. All four words rhyme!"),
                        TutorialStep(icon: "hand.tap", title: "Tap to Spell", description: "Tap letters in the pyramid or use the keyboard to spell each word. Every letter is used exactly once across all four words."),
                        TutorialStep(icon: "arrow.right.arrow.left", title: "Navigate Words", description: "Tap any answer row to select it. Words auto-advance when filled. Backspace moves to the previous word if the current one is empty."),
                    ],
                    confettiColors: [.rhymeAGramsAccent, .yellow, .green, .white],
                    shareCardBuilder: { vm in
                        let streak = StreakManager.streakInfo().rhymeAGramsStreak
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

    let onBackToHome: () -> Void
    @State private var route: Route = .loading
    @StateObject private var viewModel = TumblePunsViewModel()

    var body: some View {
        Group {
            switch route {
            case .loading:
                TumblePunsLoadingView(
                    date: Date(),
                    onStart: {
                        route = .playing
                    },
                    onBack: onBackToHome
                )
            case .playing:
                GameFlowView(
                    viewModel: viewModel,
                    gameName: "TumblePuns",
                    gameDescription: "Unscramble words and solve the punny definition",
                    iconView: TumblePunsIconView(size: 80),
                    tutorialSteps: [
                        TutorialStep(icon: "circle.grid.3x3", title: "Welcome to TumblePuns", description: "Unscramble four jumbled words, then use the highlighted letters to solve a punny clue."),
                        TutorialStep(icon: "arrow.triangle.2.circlepath", title: "Unscramble Words", description: "Tap a word to select it, then type the correct spelling. Use the shuffle button to rearrange the scrambled letters for a fresh look."),
                        TutorialStep(icon: "paintbrush.pointed", title: "Shaded Letters", description: "Each solved word reveals its shaded letters. These special letters combine to form the final answer."),
                        TutorialStep(icon: "lightbulb", title: "Solve the Pun", description: "Read the definition clue, then unscramble the shaded letters to complete the punny final answer."),
                    ],
                    confettiColors: [.tumblePunsAccent, .yellow, .red, .white],
                    shareCardBuilder: { vm in
                        let streak = StreakManager.streakInfo().tumblePunsStreak
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
