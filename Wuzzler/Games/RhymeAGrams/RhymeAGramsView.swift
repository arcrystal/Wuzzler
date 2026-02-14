import SwiftUI

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct RhymeAGramsView: View {
    @StateObject var viewModel: RhymeAGramsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.gameAccent) private var gameAccent
    let onBackToHome: () -> Void

    @State private var showHub: Bool = true
    @State private var gameCleared: Bool = false
    @State private var showTutorial: Bool = false

    private var tutorialSteps: [TutorialStep] {
        [
            TutorialStep(icon: "triangle", title: "Welcome to RhymeAGrams", description: "Find four 4-letter rhyming words hidden in the pyramid of letters. All four words rhyme!"),
            TutorialStep(icon: "hand.tap", title: "Tap to Spell", description: "Tap letters in the pyramid or use the keyboard to spell each word. Every letter is used exactly once across all four words."),
            TutorialStep(icon: "arrow.right.arrow.left", title: "Navigate Words", description: "Tap any answer row to select it. Words auto-advance when filled. Backspace moves to the previous word if the current one is empty."),
        ]
    }

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
                gameView
            }
        }
        .onAppear {
            if !viewModel.started {
                // Coming from loading screen - start the game and go directly to game
                viewModel.startGame()
                showHub = false
            } else {
                // Returning to paused or completed game - show hub
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showHub = true
                }
            }
        }
    }

    // MARK: - Hub
    private var startHub: some View {
        VStack(spacing: 0) {

            VStack(spacing: 16) {
                Spacer()
                RhymeAGramsIconView(size: 80)

                Text("RhymeAGrams")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Find four 4-letter rhyming words from a pyramid of letters")
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

            // Bottom content - state-specific
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

                case .completed:
                    Text("Great job!")
                        .font(.title3.weight(.semibold))

                    Text("Time: \(String(format: "%02d:%02d", Int(viewModel.finishTime) / 60, Int(viewModel.finishTime) % 60))")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()

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
    }

    // MARK: - Game View
    private var gameView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    UIApplication.shared.endEditing()
                    viewModel.pause()
                    showHub = true
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .font(.headline)
                }

                Spacer()

                Text("RhymeAGrams")
                    .font(.headline)

                Spacer()

                if viewModel.started && !viewModel.finished {
                    HStack(spacing: 8) {
                        Text(viewModel.elapsedTimeString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        Button {
                            viewModel.pause()
                            showHub = true
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
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

            VStack(spacing: 20) {
                Spacer()

                // Pyramid (also acts as a tappable keyboard)
                PyramidView(letters: viewModel.puzzle.letters,
                            usedPositions: viewModel.usedPyramidPositions,
                            onLetterTap: { letter in
                                viewModel.typeKey(letter)
                            })
                    .padding(.horizontal)

                Spacer()

                // Answer slots
                AnswerSlotsView(
                    answers: viewModel.answers,
                    selectedSlot: viewModel.selectedSlot,
                    correctIndices: viewModel.correctAnswerIndices,
                    isSolved: viewModel.finished,
                    bounceIndex: viewModel.winBounceIndex,
                    onSelectSlot: { index in
                        viewModel.selectSlot(index)
                    }
                )
                .padding(.horizontal)

                Spacer()

                // Keyboard
                if !viewModel.finished {
                    KeyboardView(
                        onKeyTap: { key in
                            viewModel.typeKey(key)
                        },
                        onDelete: {
                            viewModel.deleteKey()
                        }
                    )
                    .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical)
            .modifier(Shake(animatableData: CGFloat(viewModel.shakeTrigger)))
        }
        .overlay(alignment: .bottom) {
            if viewModel.showIncorrectFeedback {
                IncorrectToastView()
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.boardCell.opacity(0.2).ignoresSafeArea())
    }
}

// MARK: - Pyramid View
private struct PyramidView: View {
    @Environment(\.gameAccent) private var gameAccent
    let letters: [String]
    let usedPositions: [[Bool]]
    var onLetterTap: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(letters.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, letter in
                        let isUsed = usedPositions[rowIndex][colIndex]
                        Text(String(letter))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(gameAccent.opacity(0.3))
                            )
                            .contentShape(Rectangle())
                            .opacity(isUsed ? 0.25 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: isUsed)
                            .onTapGesture {
                                if !isUsed {
                                    onLetterTap?(String(letter))
                                }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Answer Slots View
private struct AnswerSlotsView: View {
    let answers: [String]
    let selectedSlot: Int
    let correctIndices: Set<Int>
    let isSolved: Bool
    let bounceIndex: Int?
    let onSelectSlot: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                AnswerSlotRow(
                    answer: answers[index],
                    isSelected: selectedSlot == index && !isSolved,
                    isCorrect: correctIndices.contains(index),
                    isSolved: isSolved,
                    shouldBounce: bounceIndex == index,
                    onTap: {
                        onSelectSlot(index)
                    }
                )
            }
        }
    }
}

private struct AnswerSlotRow: View {
    @Environment(\.gameAccent) private var gameAccent
    let answer: String
    let isSelected: Bool
    let isCorrect: Bool
    let isSolved: Bool
    let shouldBounce: Bool
    let onTap: () -> Void

    /// Index of the next letter to be typed (0-3), or 4 if full
    private var cursorIndex: Int { answer.count }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                let letter = index < answer.count ? String(answer[answer.index(answer.startIndex, offsetBy: index)]) : ""
                let isCursor = isSelected && index == cursorIndex
                Text(letter)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(cellBackground(index: index, isCursor: isCursor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(borderColor, lineWidth: isSelected ? 2.5 : 1)
                            )
                    )
                    .scaleEffect(shouldBounce ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: shouldBounce)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isSolved {
                onTap()
            }
        }
    }

    private func cellBackground(index: Int, isCursor: Bool) -> Color {
        if isSolved && isCorrect {
            return gameAccent.opacity(0.3)
        } else if isCursor {
            return gameAccent.opacity(0.18)
        } else if isSelected {
            return gameAccent.opacity(0.08)
        } else {
            return Color.boardCell
        }
    }

    private var borderColor: Color {
        if isSelected {
            return gameAccent
        } else {
            return Color.gridLine
        }
    }
}

// MARK: - Feedback Effects

private struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

private struct IncorrectToastView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.small)
            Text("Not quite\u{2014}keep going")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 2, y: 1)
    }
}

