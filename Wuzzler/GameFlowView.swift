import SwiftUI

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Shared wrapper view for all Wuzzler games. Provides the hub (not-started /
/// in-progress / completed), header bar, celebration overlays, scene-phase
/// handling, tutorial, and share sheet. Game-specific content is injected via
/// the `gameContent` closure.
struct GameFlowView<GameContent: View, IconView: View, VM: GameFlowViewModel>: View {
    @ObservedObject var viewModel: VM
    let gameName: String
    let gameDescription: String
    let iconView: IconView
    let tutorialSteps: [TutorialStep]
    let confettiColors: [Color]
    let shareCardBuilder: (VM) -> String
    let gameContent: (@escaping () -> Void) -> GameContent
    let onBackToHome: () -> Void
    /// Optional extra action to run when leaving the hub (e.g. dismiss keyboard, hide input).
    var onExitHub: (() -> Void)? = nil
    /// Optional extra action to run on appear if extra init is needed (e.g. TumblePuns letter positions).
    var onExtraAppear: (() -> Void)? = nil
    /// Delay before transitioning to hub after win. Games with their own
    /// post-win sequence (like Diagone's row highlights) can set this higher.
    var hubTransitionDelay: TimeInterval = 2.5

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.gameAccent) private var gameAccent

    @State private var showHub: Bool = true
    @State private var gameCleared: Bool = false
    @State private var showTutorial: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareText: String = ""
    @State private var confettiTrigger: Int = 0
    @State private var showPersonalBest: Bool = false
    @State private var showMilestone: Bool = false
    @State private var milestoneStreak: Int = 0

    private enum HubMode { case notStarted, inProgress, completed }
    private var hubMode: HubMode {
        if viewModel.finished {
            return .completed
        } else if viewModel.started || gameCleared {
            return .inProgress
        } else {
            return .notStarted
        }
    }

    var body: some View {
        Group {
            if showHub {
                startHub
            } else {
                gameContent({
                    viewModel.pause()
                    showHub = true
                })
            }
        }
        .overlay {
            ConfettiView(trigger: confettiTrigger, colors: confettiColors)
        }
        .overlay {
            PersonalBestToast(isShowing: $showPersonalBest)
        }
        .overlay {
            MilestoneToast(streakCount: milestoneStreak, isShowing: $showMilestone)
        }
        .onAppear {
            onExtraAppear?()
            if !viewModel.started {
                viewModel.startGame()
                showHub = false
            } else {
                showHub = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                if viewModel.started && !viewModel.finished {
                    viewModel.pause()
                    showHub = true
                }
            }
        }
        .onChange(of: viewModel.finished) { _, didFinish in
            if didFinish {
                UIApplication.shared.endEditing()
                confettiTrigger += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + hubTransitionDelay) {
                    showHub = true
                }
                // Personal best check
                if StreakManager.isPersonalBest(game: viewModel.gameType, time: viewModel.finishTime) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { showPersonalBest = true }
                    }
                }
                // Streak milestone check
                let streak = streakForCurrentGame()
                if [7, 14, 30, 50, 100, 365].contains(streak) || (streak > 0 && streak % 100 == 0) {
                    milestoneStreak = streak
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation { showMilestone = true }
                    }
                }
            }
        }
        .onChange(of: showHub) { _, isShowing in
            if !isShowing {
                UIApplication.shared.endEditing()
                DispatchQueue.main.async {
                    UIApplication.shared.endEditing()
                }
                onExitHub?()
            }
        }
    }

    private func streakForCurrentGame() -> Int {
        let info = StreakManager.streakInfo()
        switch viewModel.gameType {
        case .diagone: return info.diagoneStreak
        case .rhymeAGrams: return info.rhymeAGramsStreak
        case .tumblePuns: return info.tumblePunsStreak
        }
    }

    // MARK: - Hub

    private var startHub: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Spacer()
                iconView

                Text(gameName)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(gameDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)

                Button(action: { showTutorial = true }) {
                    Label("How to Play", systemImage: "questionmark.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(gameAccent)
                }
            }

            Spacer()

            VStack(spacing: 16) {
                switch hubMode {
                case .notStarted:
                    Button(action: {
                        UIApplication.shared.endEditing()
                        viewModel.startGame()
                        showHub = false
                    }) {
                        Text("Play")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(gameAccent)
                            .cornerRadius(12)
                    }

                case .inProgress:
                    Text(gameCleared ? "Game cleared." : "You're in the middle of today's puzzle.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(viewModel.elapsedTimeString)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()

                    Button(action: {
                        UIApplication.shared.endEditing()
                        if gameCleared {
                            gameCleared = false
                            viewModel.startGame()
                        } else {
                            viewModel.resume()
                        }
                        showHub = false
                    }) {
                        Text(gameCleared ? "Play" : "Resume")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(gameAccent)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        UIApplication.shared.endEditing()
                        viewModel.clearGame()
                        gameCleared = true
                    }) {
                        Text("Clear Game")
                            .font(.headline)
                            .foregroundColor(gameAccent)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(gameAccent, lineWidth: 2)
                            )
                    }
                    .opacity(gameCleared ? 0.4 : 1.0)
                    .disabled(gameCleared)

                    backToHomeButton

                case .completed:
                    Text("Great job!")
                        .font(.title3.weight(.semibold))

                    Text("Time: \(String(format: "%02d:%02d", Int(viewModel.finishTime) / 60, Int(viewModel.finishTime) % 60))")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()

                    Button {
                        shareText = shareCardBuilder(viewModel)
                        showShareSheet = true
                    } label: {
                        Label("Share Results", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(gameAccent)
                    }

                    Text("Check back tomorrow for a new puzzle!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: {
                        UIApplication.shared.endEditing()
                        showHub = false
                        viewModel.runWinSequence()
                    }) {
                        Text("View Today's Puzzle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(gameAccent)
                            .cornerRadius(12)
                    }

                    backToHomeButton
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.boardCell.opacity(0.2).ignoresSafeArea())
        .overlay {
            if showTutorial {
                TutorialOverlay(steps: tutorialSteps, accentColor: gameAccent, onDismiss: { showTutorial = false })
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareActivityView(items: [shareText])
        }
    }

    private var backToHomeButton: some View {
        Button(action: onBackToHome) {
            Text("Back to Home")
                .font(.headline)
                .foregroundColor(gameAccent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(gameAccent, lineWidth: 2)
                )
        }
    }

    // MARK: - Header (public for game views to use)

    static func header(viewModel: VM, gameName: String, gameAccent: Color, onPause: @escaping () -> Void) -> some View {
        HStack {
            Button {
                UIApplication.shared.endEditing()
                onPause()
            } label: {
                Label("Back", systemImage: "chevron.backward")
                    .font(.headline)
            }

            Spacer()

            Text(gameName)
                .font(.headline)

            Spacer()

            if viewModel.started && !viewModel.finished {
                HStack(spacing: 8) {
                    Text(viewModel.elapsedTimeString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    Button {
                        onPause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Pause Game")
                }
                .frame(width: 75, alignment: .trailing)
            } else if viewModel.started && viewModel.finished {
                Text(viewModel.elapsedTimeString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(width: 75, alignment: .trailing)
            } else {
                Color.clear.frame(width: 75)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.boardCell.opacity(0.1))
    }
}

/// A helper view that builds the standard game header. Game views use this
/// directly so they don't need to call the static method with all the params.
struct GameHeader<VM: GameFlowViewModel>: View {
    @ObservedObject var viewModel: VM
    let gameName: String
    @Environment(\.gameAccent) private var gameAccent
    let onPause: () -> Void

    var body: some View {
        GameFlowView<EmptyView, EmptyView, VM>.header(
            viewModel: viewModel,
            gameName: gameName,
            gameAccent: gameAccent,
            onPause: onPause
        )
    }
}
