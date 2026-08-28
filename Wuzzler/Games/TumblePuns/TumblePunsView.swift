import SwiftUI

/// Game-specific content for TumblePuns. Wrapped by GameFlowView in the coordinator.
struct TumblePunsGameView: View {
    @ObservedObject var viewModel: TumblePunsViewModel
    @Environment(\.gameAccent) private var gameAccent
    let onPause: () -> Void

    /// For each word (4 total), stores the display position for each letter index.
    @State private var letterPositions: [[Int]] = []

    /// All words and the final answer start their wave simultaneously. Letters
    /// within each answer are staggered by 0.08s.
    private func waveDelay(letterIndex: Int) -> Double {
        0.05 + 0.08 * Double(letterIndex)
    }

    private func initializeLetterPositions() {
        guard letterPositions.isEmpty else { return }
        letterPositions = viewModel.puzzle.words.map { word in
            Array(0..<word.scrambled.count).shuffled()
        }
    }

    private func shuffleWord(_ wordIndex: Int) {
        guard wordIndex < letterPositions.count else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            letterPositions[wordIndex] = letterPositions[wordIndex].shuffled()
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                GameHeader(viewModel: viewModel, gameName: "TumblePun", onPause: onPause)

                if viewModel.allWordsFilled {
                    stageSwitcher
                        .padding(.vertical, 4)
                }

                GeometryReader { contentGeo in
                    focusContent(size: contentGeo.size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }

                keyboardView
                    .padding(.top, 8)
                    .padding(.bottom, max(8, geo.safeAreaInsets.bottom + 4))
                    .background(Color(UIColor.systemBackground).opacity(0.96))
            }
            .modifier(Shake(animatableData: CGFloat(viewModel.shakeTrigger)))
            .overlay(alignment: .bottom) {
                if viewModel.showIncorrectFeedback {
                    IncorrectToastView()
                        .padding(.bottom, 170)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color.boardCell.opacity(0.2).ignoresSafeArea())
            .onAppear { initializeLetterPositions() }
        }
    }

    // MARK: - Completed-word Navigation

    private var stageSwitcher: some View {
        HStack(spacing: 2) {
            stageSwitchButton(title: "Words", systemImage: "circle.grid.2x2.fill", isSelected: !viewModel.isFinalAnswerSelected) {
                viewModel.selectWord(0)
            }
            stageSwitchButton(title: "Clue", systemImage: "lightbulb.fill", isSelected: viewModel.isFinalAnswerSelected) {
                viewModel.selectFinalAnswer()
            }
        }
        .padding(3)
        .frame(width: 190, height: 36)
        .background(Color.boardCell, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.gridLine, lineWidth: 1))
        .accessibilityIdentifier("tumble-stage-switcher")
    }

    private func stageSwitchButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? gameAccent : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Puzzle Content

    @ViewBuilder
    private func focusContent(size: CGSize) -> some View {
        if viewModel.allWordsFilled && viewModel.isFinalAnswerSelected {
            finalAnswerStage(size: size)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            wordsGrid(size: size)
                .transition(.opacity)
        }
    }

    private func wordsGrid(size: CGSize) -> some View {
        let outerPadding: CGFloat = size.width < 360 ? 6 : 10
        let horizontalSpacing: CGFloat = size.width < 360 ? 4 : 8
        let verticalSpacing: CGFloat = 6
        let columnWidth = max(120, (size.width - outerPadding * 2 - horizontalSpacing) / 2)
        let rowHeight = max(140, (size.height - outerPadding * 2 - verticalSpacing) / 2)

        return Grid(horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing) {
            GridRow {
                wordSection(index: 0, availableSize: CGSize(width: columnWidth, height: rowHeight))
                wordSection(index: 1, availableSize: CGSize(width: columnWidth, height: rowHeight))
            }
            GridRow {
                wordSection(index: 2, availableSize: CGSize(width: columnWidth, height: rowHeight))
                wordSection(index: 3, availableSize: CGSize(width: columnWidth, height: rowHeight))
            }
        }
        .padding(outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("tumble-words-grid")
    }

    private func wordSection(index: Int, availableSize: CGSize) -> some View {
        let word = viewModel.puzzle.words[index]
        let isCorrect = viewModel.correctWordIndices.contains(index)
        let isSelected = viewModel.selectedWordIndex == index
        let letterCount = word.scrambled.count
        let positions = index < letterPositions.count ? letterPositions[index] : Array(0..<letterCount)
        let answerSpacing: CGFloat = 1
        let rawAnswerCellWidth = (
            availableSize.width - CGFloat(max(word.solution.count - 1, 0)) * answerSpacing
        ) / CGFloat(max(word.solution.count, 1))
        let answerCellWidth = min(availableSize.width > 300 ? 36 : 30, max(15, rawAnswerCellWidth))
        let answerCellHeight = min(availableSize.width > 300 ? 40 : 34, max(27, answerCellWidth * 1.35))
        let wheelSize = min(
            availableSize.width,
            max(112, availableSize.height - answerCellHeight - 5),
            availableSize.width > 300 ? 340 : 220
        )
        let wheelTileSize = min(60, max(29, wheelSize * 0.245))
        let wheelRadius = max(0, (wheelSize - wheelTileSize) / 2 - 1)

        return VStack(spacing: 5) {
            ZStack {
                ForEach(Array(word.scrambled.enumerated()), id: \.offset) { letterIndex, letter in
                    let position = letterIndex < positions.count ? positions[letterIndex] : letterIndex
                    let angle = Angle(degrees: Double(position) * (360.0 / Double(letterCount)) - 90)

                    Text(String(letter))
                        .font(.system(size: max(17, wheelTileSize * 0.56), weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(width: wheelTileSize, height: wheelTileSize)
                        .background(
                            Circle()
                                .fill(Color.boardCell)
                                .shadow(color: .black.opacity(0.1), radius: 1.5, y: 1)
                        )
                        .overlay(
                            Circle().strokeBorder(gameAccent.opacity(0.35), lineWidth: 1.25)
                        )
                        .offset(x: wheelRadius * cos(angle.radians), y: wheelRadius * sin(angle.radians))
                }

                if isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(gameAccent)
                        .accessibilityHidden(true)
                } else if !viewModel.finished {
                    Button {
                        shuffleWord(index)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Shuffle word \(index + 1)")
                }
            }
            .frame(width: wheelSize, height: wheelSize)

            HStack(spacing: answerSpacing) {
                ForEach(0..<word.solution.count, id: \.self) { letterIndex in
                    let userAnswer = viewModel.wordAnswers[index]
                    let displayLetter = letterIndex < userAnswer.count
                        ? String(userAnswer[userAnswer.index(userAnswer.startIndex, offsetBy: letterIndex)])
                        : ""
                    let isShaded = word.shadedIndices.contains(letterIndex + 1)

                    Text(displayLetter)
                        .font(.system(size: min(20, max(15, answerCellWidth * 0.82)), weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(width: answerCellWidth, height: answerCellHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isShaded ? gameAccent.opacity(isSelected ? 0.42 : 0.3) : Color.boardCell)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(isSelected ? gameAccent : Color.gridLine, lineWidth: isSelected ? 2 : 1)
                        )
                        .keyframeAnimator(initialValue: WinBounceState(), trigger: viewModel.winWaveTrigger) { content, state in
                            content.scaleEffect(state.scale)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                CubicKeyframe(1.0, duration: waveDelay(letterIndex: letterIndex))
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
        }
        .frame(width: availableSize.width, height: availableSize.height)
        .contentShape(Rectangle())
        .onTapGesture {
            if !viewModel.finished {
                viewModel.selectWord(index)
            }
        }
        .accessibilityIdentifier("tumble-word-\(index + 1)")
    }

    // MARK: - Clue and Final Answer

    private func finalAnswerStage(size: CGSize) -> some View {
        let pattern = viewModel.puzzle.answerPattern
        let compact = size.height < 330
        let horizontalPadding: CGFloat = size.width < 360 ? 12 : 20
        let answerWidth = max(120, min(size.width, 680) - horizontalPadding * 2)
        let cellSpacing: CGFloat = 4
        let minimumCellWidth: CGFloat = compact ? 16 : 18
        let maxColumns = max(1, Int((answerWidth + cellSpacing) / (minimumCellWidth + cellSpacing)))
        let rows = TumblePunsAnswerLayout.rows(for: pattern, maxColumns: maxColumns)
        let widestRow = rows.map(\.count).max() ?? 1
        let fittedCellWidth = (answerWidth - CGFloat(max(widestRow - 1, 0)) * cellSpacing)
            / CGFloat(max(widestRow, 1))
        let cellWidth = min(size.width < 360 ? 32 : 38, max(12, fittedCellWidth))
        let cellHeight: CGFloat = compact ? 38 : 44
        let shadedLetters = viewModel.enteredShadedLetters.map(String.init).joined(separator: " ")

        return VStack(spacing: compact ? 6 : 10) {
            VStack(spacing: 4) {
                Text("Clue")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(gameAccent)

                Text(viewModel.puzzle.definition)
                    .font(compact ? Font.subheadline.weight(.semibold) : Font.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("tumble-clue")

            VStack(spacing: 3) {
                Text("Shaded letters")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(shadedLetters)
                    .font(.system(size: compact ? 19 : 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(gameAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack {
                Text("Final Answer")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if !viewModel.finalAnswer.isEmpty && !viewModel.finished {
                    Button {
                        viewModel.clearFinalAnswer()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.secondary)
                    .accessibilityLabel("Clear final answer")
                }
            }

            VStack(spacing: 4) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, offsets in
                    HStack(spacing: cellSpacing) {
                        ForEach(offsets, id: \.self) { offset in
                            finalAnswerCell(pattern: pattern, offset: offset, width: cellWidth, height: cellHeight)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                if !viewModel.finished {
                    viewModel.selectFinalAnswer()
                }
            }
            .accessibilityLabel("Final answer")
            .accessibilityIdentifier("tumble-final-answer")
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, compact ? 2 : 8)
        .frame(maxWidth: min(size.width, 680), maxHeight: .infinity)
    }

    @ViewBuilder
    private func finalAnswerCell(pattern: String, offset: Int, width: CGFloat, height: CGFloat) -> some View {
        let patternIndex = pattern.index(pattern.startIndex, offsetBy: offset)
        let character = pattern[patternIndex]

        if character == "_" {
            let letterIndex = pattern.prefix(offset + 1).filter { $0 == "_" }.count - 1
            let displayLetter = letterIndex < viewModel.finalAnswer.count
                ? String(viewModel.finalAnswer[viewModel.finalAnswer.index(viewModel.finalAnswer.startIndex, offsetBy: letterIndex)])
                : ""

            Text(displayLetter)
                .font(.system(size: min(22, max(11, width * 0.58)), weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(gameAccent.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(gameAccent, lineWidth: 2)
                )
                .keyframeAnimator(initialValue: WinBounceState(), trigger: viewModel.winWaveTrigger) { content, state in
                    content.scaleEffect(state.scale)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.0, duration: waveDelay(letterIndex: letterIndex))
                        SpringKeyframe(1.35, duration: 0.18, spring: .init(response: 0.36, dampingRatio: 0.62))
                        SpringKeyframe(1.0, duration: 0.32, spring: .init(response: 0.40, dampingRatio: 0.72))
                    }
                }
        } else {
            Text(String(character))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 12, height: height)
        }
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
        .accessibilityIdentifier("tumble-keyboard")
    }
}

/// Builds final-answer rows without ever splitting a word. A single word,
/// including a hyphenated word, always remains on one line and scales to fit.
/// Multi-word answers wrap greedily only at whitespace boundaries.
enum TumblePunsAnswerLayout {
    static func rows(for pattern: String, maxColumns: Int) -> [[Int]] {
        guard !pattern.isEmpty else { return [] }

        let characters = Array(pattern)
        var words: [[Int]] = []
        var separators: [[Int]] = []
        var currentWord: [Int] = []
        var currentSeparator: [Int] = []

        for (offset, character) in characters.enumerated() {
            if character.isWhitespace {
                if !currentWord.isEmpty {
                    words.append(currentWord)
                    currentWord = []
                }
                currentSeparator.append(offset)
            } else {
                if !currentSeparator.isEmpty {
                    separators.append(currentSeparator)
                    currentSeparator = []
                }
                currentWord.append(offset)
            }
        }

        if !currentWord.isEmpty {
            words.append(currentWord)
        }

        guard !words.isEmpty else { return [Array(characters.indices)] }

        var rows: [[Int]] = []
        var row = words[0]

        for wordIndex in words.indices.dropFirst() {
            let separator = wordIndex - 1 < separators.count ? separators[wordIndex - 1] : []
            let word = words[wordIndex]
            let proposedCount = row.count + separator.count + word.count

            if proposedCount > max(1, maxColumns) {
                rows.append(row)
                row = word
            } else {
                row.append(contentsOf: separator)
                row.append(contentsOf: word)
            }
        }

        rows.append(row)
        return rows
    }
}

// MARK: - Win Wave Animation

private struct WinBounceState { var scale: CGFloat = 1.0 }
