import SwiftUI

/// Game-specific content for TumblePuns. Wrapped by GameFlowView in the coordinator.
struct TumblePunsGameView: View {
    @ObservedObject var viewModel: TumblePunsViewModel
    @Environment(\.gameAccent) private var gameAccent
    let onPause: () -> Void

    /// For each word (4 total), stores the display position for each letter index.
    @State private var letterPositions: [[Int]] = []

    /// Compute the wave delay for a letter at a given absolute position in the sequence.
    /// All words and the final answer start their wave simultaneously.
    /// Letters within each word/answer are staggered by 0.08s.
    private func waveDelay(wordIndex: Int, letterIndex: Int) -> Double {
        0.05 + 0.08 * Double(letterIndex)
    }

    private func finalAnswerWaveDelay(letterIndex: Int) -> Double {
        0.05 + 0.08 * Double(letterIndex)
    }

    /// Initialize letter positions with random shuffles for each word
    func initializeLetterPositions() {
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
        VStack(spacing: 0) {
            GameHeader(viewModel: viewModel, gameName: "TumblePun", onPause: onPause)

            ScrollView {
                VStack(spacing: 24) {
                    wordsGrid
                    definitionSection
                    finalAnswerSection
                    keyboardView
                }
                .padding(.vertical, 20)
            }
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
        .onAppear { initializeLetterPositions() }
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
            ZStack {
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
                                .fill(Color.boardCell)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    gameAccent.opacity(0.35),
                                    lineWidth: 1.5
                                )
                        )
                        .offset(x: radius * cos(angle.radians), y: radius * sin(angle.radians))
                }

                if !isCorrect && !viewModel.finished {
                    Button {
                        shuffleWord(index)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Shuffle letters")
                }
            }
            .frame(width: 85, height: 85)

            HStack(spacing: 2) {
                ForEach(0..<word.solution.count, id: \.self) { letterIndex in
                    let userAnswer = viewModel.wordAnswers[index]
                    let displayLetter = letterIndex < userAnswer.count ? String(userAnswer[userAnswer.index(userAnswer.startIndex, offsetBy: letterIndex)]) : ""
                    let isShaded = word.shadedIndices.contains(letterIndex + 1)
                    let waveDelay = waveDelay(wordIndex: index, letterIndex: letterIndex)

                    Text(displayLetter)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 22, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isShaded ? gameAccent.opacity(isSelected ? 0.45 : 0.3) : Color.boardCell)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(
                                    isSelected ? gameAccent : Color.gray.opacity(0.4),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .keyframeAnimator(initialValue: WinBounceState(), trigger: viewModel.winWaveTrigger) { content, state in
                            content.scaleEffect(state.scale)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                CubicKeyframe(1.0, duration: waveDelay)
                                SpringKeyframe(1.45, duration: 0.18, spring: .init(response: 0.36, dampingRatio: 0.62))
                                SpringKeyframe(1.0, duration: 0.32, spring: .init(response: 0.40, dampingRatio: 0.72))
                            }
                        }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !viewModel.finished {
                    viewModel.selectWord(index)
                }
            }
            .accessibilityLabel("Word \(index + 1) answer")
            .overlay(alignment: .topTrailing) {
                if !viewModel.wordAnswers[index].isEmpty && !isCorrect && !viewModel.finished {
                    Button {
                        viewModel.clearWord(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .contentShape(Circle().scale(2.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear word \(index + 1)")
                    .offset(x: 16, y: -16)
                    .zIndex(1)
                    .transition(.opacity)
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

            if viewModel.areWordsSolved {
                Text("Shaded letters: \(viewModel.shadedLetters)")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }

            let pattern = viewModel.puzzle.answerPattern
            HStack(spacing: 4) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { offset, char in
                    if char == "_" {
                        let letterIndex = pattern.prefix(offset + 1).filter { $0 == "_" }.count - 1
                        let userAnswer = viewModel.finalAnswer
                        let displayLetter = letterIndex < userAnswer.count ? String(userAnswer[userAnswer.index(userAnswer.startIndex, offsetBy: letterIndex)]) : ""
                        let finalDelay = finalAnswerWaveDelay(letterIndex: letterIndex)

                        Text(displayLetter)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 34, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(gameAccent.opacity(0.3))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(
                                        viewModel.isFinalAnswerSelected ? gameAccent : Color.gray.opacity(0.4),
                                        lineWidth: viewModel.isFinalAnswerSelected ? 2 : 1
                                    )
                            )
                            .keyframeAnimator(initialValue: WinBounceState(), trigger: viewModel.winWaveTrigger) { content, state in
                                content.scaleEffect(state.scale)
                            } keyframes: { _ in
                                KeyframeTrack(\.scale) {
                                    CubicKeyframe(1.0, duration: finalDelay)
                                    SpringKeyframe(1.35, duration: 0.18, spring: .init(response: 0.36, dampingRatio: 0.62))
                                    SpringKeyframe(1.0, duration: 0.32, spring: .init(response: 0.40, dampingRatio: 0.72))
                                }
                            }
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
            .accessibilityLabel("Final answer")
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

// MARK: - Win Wave Animation

private struct WinBounceState { var scale: CGFloat = 1.0 }
