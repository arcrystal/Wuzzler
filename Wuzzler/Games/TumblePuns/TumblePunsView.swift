import SwiftUI

struct TumblePunsView: View {
    @ObservedObject var viewModel: TumblePunsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    let onBackToHome: () -> Void

    @State private var showHub: Bool = true
    @State private var gameCleared: Bool = false

    /// For each word (4 total), stores the display position for each letter index.
    /// letterPositions[wordIndex][letterIndex] = position on circle (0..<letterCount)
    @State private var letterPositions: [[Int]] = []

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

    /// Initialize letter positions with random shuffles for each word
    private func initializeLetterPositions() {
        guard letterPositions.isEmpty else { return }
        letterPositions = viewModel.puzzle.words.map { word in
            Array(0..<word.scrambled.count).shuffled()
        }
    }

    /// Shuffle the letters for a specific word with animation
    private func shuffleWord(_ wordIndex: Int) {
        guard wordIndex < letterPositions.count else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            letterPositions[wordIndex] = letterPositions[wordIndex].shuffled()
        }
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.18) : Color.boardCell.opacity(0.2))
                .ignoresSafeArea()

            if showHub {
                startHub
            } else {
                gameView
            }
        }
        .onAppear {
            initializeLetterPositions()
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
        .onChange(of: viewModel.finished) { _, finished in
            if finished {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showHub = true
                }
            }
        }
    }

    // MARK: - Start Hub
    private var startHub: some View {
        VStack(spacing: 0) {
        
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "circle")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.mainDiagonal)

                Text("TumblePuns")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Unscramble words and solve the punny definition")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
            }

            Spacer()

            // Bottom content - state-specific
            VStack(spacing: 16) {
                switch hubMode {
                case .notStarted:
                    Button(action: {
                        viewModel.startGame()
                        showHub = false
                    }) {
                        Text("Play")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.mainDiagonal)
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
                            .background(Color.mainDiagonal)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        viewModel.clearGame()
                        gameCleared = true
                    }) {
                        Text("Clear Game")
                            .font(.headline)
                            .foregroundColor(.mainDiagonal)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.mainDiagonal, lineWidth: 2)
                            )
                    }
                    .opacity(gameCleared ? 0.4 : 1.0)
                    .disabled(gameCleared)

                    Button(action: onBackToHome) {
                        Text("Back to Home")
                            .font(.headline)
                            .foregroundColor(.mainDiagonal)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.mainDiagonal, lineWidth: 2)
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
                        showHub = false
                        viewModel.runWinSequence()
                    }) {
                        Text("View Today's Puzzle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.mainDiagonal)
                            .cornerRadius(12)
                    }

                    Button(action: onBackToHome) {
                        Text("Back to Home")
                            .font(.headline)
                            .foregroundColor(.mainDiagonal)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.mainDiagonal, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Game View
    private var gameView: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView {
                VStack(spacing: 24) {
                    wordsGrid
                    definitionSection
                    finalAnswerSection
                    keyboardView
                }
                .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: {
                viewModel.pause()
                showHub = true
            }) {
                Label("Back", systemImage: "chevron.backward")
                    .font(.headline)
            }

            Spacer()

            Text("TumblePuns")
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
        .background(colorScheme == .dark ? Color(red: 0.15, green: 0.16, blue: 0.22) : Color.boardCell.opacity(0.1))
    }

    // MARK: - Words Grid
    private var wordsGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                wordSection(index: 0)
                wordSection(index: 1)
            }
            HStack(spacing: 16) {
                wordSection(index: 2)
                wordSection(index: 3)
            }
        }
        .padding(.horizontal, 16)
    }

    private func wordSection(index: Int) -> some View {
        let word = viewModel.puzzle.words[index]
        let isCorrect = viewModel.correctWordIndices.contains(index)
        let isSelected = viewModel.selectedWordIndex == index
        let letterCount = word.scrambled.count
        let positions = index < letterPositions.count ? letterPositions[index] : Array(0..<letterCount)

        return VStack(spacing: 10) {
            // Scrambled letters arranged in a circle with shuffle button
            ZStack {
                // Letter circles
                ForEach(Array(word.scrambled.enumerated()), id: \.offset) { letterIdx, letter in
                    let position = letterIdx < positions.count ? positions[letterIdx] : letterIdx
                    let angle = Angle(degrees: Double(position) * (360.0 / Double(letterCount)) - 90)
                    let radius: CGFloat = 30

                    Text(String(letter))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color(red: 0.25, green: 0.25, blue: 0.3) : Color.boardCell)
                                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 2, x: 0, y: 1)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    colorScheme == .dark ? Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.6) : Color.mainDiagonal.opacity(0.35),
                                    lineWidth: 1.5
                                )
                        )
                        .offset(x: radius * cos(angle.radians), y: radius * sin(angle.radians))
                }

                // Shuffle button in center
                if !isCorrect && !viewModel.finished {
                    Button {
                        shuffleWord(index)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? Color(red: 0.6, green: 0.75, blue: 1.0) : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 85, height: 85)

            // Answer boxes
            HStack(spacing: 2) {
                ForEach(0..<word.solution.count, id: \.self) { letterIndex in
                    let userAnswer = viewModel.wordAnswers[index]
                    let displayLetter = letterIndex < userAnswer.count ? String(userAnswer[userAnswer.index(userAnswer.startIndex, offsetBy: letterIndex)]) : ""
                    let isShaded = word.shadedIndices.contains(letterIndex + 1)
                    let shouldBounce = viewModel.winBounceIndex == index

                    Text(displayLetter)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isCorrect ? (colorScheme == .dark ? Color(red: 0.4, green: 0.9, blue: 0.6) : .green) : .primary)
                        .frame(width: 22, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isShaded ? (colorScheme == .dark ? Color(red: 0.45, green: 0.6, blue: 1.0).opacity(0.65) : Color.mainDiagonal.opacity(isSelected ? 0.45 : 0.3)) : (colorScheme == .dark ? Color(red: 0.25, green: 0.25, blue: 0.3) : Color.boardCell))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(
                                    isCorrect ? (colorScheme == .dark ? Color(red: 0.4, green: 0.9, blue: 0.6) : .green) : (isShaded && colorScheme == .dark ? Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.8) : (isSelected ? (colorScheme == .dark ? Color(red: 0.5, green: 0.7, blue: 1.0) : Color.mainDiagonal) : Color.gray.opacity(0.4))),
                                    lineWidth: (isShaded && colorScheme == .dark) ? 1.5 : (isSelected ? 2 : 1)
                                )
                        )
                        .shadow(color: isShaded && colorScheme == .dark ? Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.3) : .clear, radius: 3, x: 0, y: 0)
                        .offset(y: shouldBounce ? -8 : 0)
                        .animation(.easeInOut(duration: 0.3), value: shouldBounce)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !viewModel.finished {
                    viewModel.selectWord(index)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Definition Section
    private var definitionSection: some View {
        VStack(spacing: 6) {
            Text("Definition:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(viewModel.puzzle.definition)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Final Answer Section
    private var finalAnswerSection: some View {
        VStack(spacing: 8) {
            Text("Final Answer")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            // Shaded letters hint (only show when all words are solved)
            if viewModel.areWordsSolved {
                Text("Shaded letters: \(viewModel.shadedLetters)")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }

            // Answer input boxes with dashes
            let pattern = viewModel.puzzle.answerPattern
            HStack(spacing: 4) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { offset, char in
                    if char == "_" {
                        let letterIndex = pattern.prefix(offset + 1).filter { $0 == "_" }.count - 1
                        let userAnswer = viewModel.finalAnswer
                        let displayLetter = letterIndex < userAnswer.count ? String(userAnswer[userAnswer.index(userAnswer.startIndex, offsetBy: letterIndex)]) : ""
                        let shouldBounce = viewModel.finalAnswerBounceIndex == letterIndex

                        Text(displayLetter)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 34, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(colorScheme == .dark ? Color(red: 0.45, green: 0.6, blue: 1.0).opacity(0.65) : Color.mainDiagonal.opacity(0.3))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(
                                        viewModel.isFinalAnswerSelected ? (colorScheme == .dark ? Color(red: 0.5, green: 0.7, blue: 1.0) : Color.mainDiagonal) : (colorScheme == .dark ? Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.8) : Color.gray.opacity(0.4)),
                                        lineWidth: colorScheme == .dark ? 1.5 : (viewModel.isFinalAnswerSelected ? 2 : 1)
                                    )
                            )
                            .shadow(color: colorScheme == .dark ? Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.3) : .clear, radius: 3, x: 0, y: 0)
                            .scaleEffect(shouldBounce ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: shouldBounce)
                    } else {
                        Text(String(char))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 12, height: 42)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !viewModel.finished {
                    viewModel.selectFinalAnswer()
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Keyboard
    private var keyboardView: some View {
        KeyboardView(
            onKeyTap: { key in
                if !viewModel.finished {
                    viewModel.typeKey(key)
                }
            },
            onDelete: {
                if !viewModel.finished {
                    viewModel.deleteKey()
                }
            }
        )
        .padding(.horizontal)
        .opacity(viewModel.finished ? 0.5 : 1.0)
    }
}
