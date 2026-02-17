import SwiftUI

/// Game-specific content for RhymeAGrams. Wrapped by GameFlowView in the coordinator.
struct RhymeAGramsGameView: View {
    @ObservedObject var viewModel: RhymeAGramsViewModel
    let onPause: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(viewModel: viewModel, gameName: "RhymeAGram", onPause: onPause)

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
                    winWaveTrigger: viewModel.winWaveTrigger,
                    onSelectSlot: { index in
                        viewModel.selectSlot(index)
                    }
                )
                .padding(.horizontal)

                Spacer()

                // Keyboard
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
private struct BounceState { var scale: CGFloat = 1.0 }

private struct AnswerSlotsView: View {
    let answers: [String]
    let selectedSlot: Int
    let correctIndices: Set<Int>
    let isSolved: Bool
    let winWaveTrigger: Int
    let onSelectSlot: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                AnswerSlotRow(
                    answer: answers[index],
                    isSelected: selectedSlot == index && !isSolved,
                    isCorrect: correctIndices.contains(index),
                    isSolved: isSolved,
                    winWaveTrigger: winWaveTrigger,
                    rowIndex: index,
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
    let winWaveTrigger: Int
    let rowIndex: Int
    let onTap: () -> Void

    private var cursorIndex: Int { answer.count }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                let letter = index < answer.count ? String(answer[answer.index(answer.startIndex, offsetBy: index)]) : ""
                let isCursor = isSelected && index == cursorIndex
                let delay = 0.05 + 0.22 * Double(rowIndex) + 0.09 * Double(index)
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
                    .keyframeAnimator(initialValue: BounceState(), trigger: winWaveTrigger) { content, state in
                        content.scaleEffect(state.scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            CubicKeyframe(1.0, duration: delay)
                            SpringKeyframe(1.18, duration: 0.18, spring: .init(response: 0.36, dampingRatio: 0.62))
                            SpringKeyframe(1.0, duration: 0.32, spring: .init(response: 0.40, dampingRatio: 0.72))
                        }
                    }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isSolved {
                onTap()
            }
        }
        .accessibilityLabel("Answer slot")
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

struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

struct IncorrectToastView: View {
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
