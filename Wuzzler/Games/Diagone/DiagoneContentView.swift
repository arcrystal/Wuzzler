import SwiftUI

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Root view composing the game interface. Contains a header with the title,
/// timer and control buttons, the board itself, the chip selection pane and
/// optionally the main diagonal input. Relies heavily on `GameViewModel` to
/// drive state and actions.
struct DiagoneContentView: View {
    @StateObject var viewModel: GameViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.gameAccent) private var gameAccent
    let onBackToHome: () -> Void

    @MainActor
    init(viewModel: GameViewModel, onBackToHome: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onBackToHome = onBackToHome
    }
    /// Local state tracking which row is currently highlighted during the win
    /// animation. This is advanced sequentially when the puzzle is solved to
    /// produce a celebratory sweep across the board.
    @State private var highlightedRow: Int? = nil
    /// Timer used to coordinate row highlighting after win. Cancelled when
    /// animation completes.
    @State private var winHighlightTimer: Timer? = nil

    @State private var showHub: Bool = true
    @State private var gameCleared: Bool = false
    @State private var showTutorial: Bool = false

    private var tutorialSteps: [TutorialStep] {
        [
            TutorialStep(icon: "square.grid.3x3", title: "Welcome to Diagone", description: "Place diagonal word chips onto a 6\u{00d7}6 board to spell six horizontal words."),
            TutorialStep(icon: "hand.draw", title: "Drag & Drop", description: "Drag chips from the tray onto the board. Each chip fills a diagonal of matching length."),
            TutorialStep(icon: "arrow.uturn.backward", title: "Rearrange Freely", description: "Drag a placed chip to a different diagonal, or drag it off the board to remove it."),
            TutorialStep(icon: "character.textbox", title: "Complete the Diagonal", description: "Once all chips are placed, type letters into the highlighted main diagonal to finish the puzzle."),
        ]
    }
    /// Random row assignment for chip pairs: true = first-by-id in row 1, false = swapped
    @State private var chipRowAssignment: [Bool] = (0..<5).map { _ in Bool.random() }

    private enum HubMode { case notStarted, inProgress, completed }
    private var hubMode: HubMode {
        if viewModel.isSolved {
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
                GeometryReader { geo in
                    let width = geo.size.width
                    VStack(spacing: 0) {
                        // Header: title, timer and control buttons
                        header

                        VStack(spacing: 20) {
                            // Board
                            BoardView(highlightRow: highlightedRow)
                                .environmentObject(viewModel)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity)
                            // Chip selection pane (hidden when all pieces placed or game finished)
                            if !viewModel.showMainInput && !viewModel.finished {
                                chipPane(width: width)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            // Keyboard (shown only when all pieces placed and not finished)
                            if viewModel.showMainInput && !viewModel.finished {
                                Spacer().frame(maxHeight: 40)
                                KeyboardView(
                                    onKeyTap: { key in
                                        viewModel.typeKey(key)
                                    },
                                    onDelete: {
                                        viewModel.deleteKey()
                                    }
                                )
                                .padding(.horizontal)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding(.vertical)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.showMainInput)
                    }
                    .background(Color.boardCell.opacity(0.2).ignoresSafeArea())
                    // Trigger row highlight animation whenever the solved flag becomes true
                    .onChange(of: viewModel.isSolved, initial: false) { oldValue, newValue in
                        if newValue {
                            startRowHighlightAnimation()
                        }
                    }
                    .overlay {
                        // Floating chip that follows the finger during board-to-board drags.
                        // Extracted into its own view so high-frequency position updates
                        // (via Combine subject) only invalidate this small overlay, not the
                        // entire game view tree.
                        FloatingChipOverlay()
                            .environmentObject(viewModel)
                    }
                }
            }
        }
        .environmentObject(viewModel)
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
                if viewModel.started && !viewModel.isSolved {
                    viewModel.pause()
                    showHub = true
                }
            }
        }
        .onChange(of: viewModel.isSolved, initial: false) { _, solved in
            if solved {
                UIApplication.shared.endEditing()
            }
        }
        .onChange(of: showHub) { _, isShowing in
            if !isShowing {
                // Extra safety: ensure keyboard is dismissed when exiting the hub
                UIApplication.shared.endEditing()
                // In case any view auto-focuses on appear, dismiss again on next runloop
                DispatchQueue.main.async {
                    UIApplication.shared.endEditing()
                }
                if viewModel.finished { viewModel.showMainInput = false }
            }
        }
        .onChange(of: viewModel.finished) { _, didFinish in
            if didFinish {
                // Ensure keyboard is dismissed immediately and after any layout updates
                UIApplication.shared.endEditing()
                viewModel.showMainInput = false
                DispatchQueue.main.async { UIApplication.shared.endEditing() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Closing/minimizing the app while editing: force dismiss
            UIApplication.shared.endEditing()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Belt-and-suspenders: also dismiss on background
            UIApplication.shared.endEditing()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // On resume, don't allow any text field to reclaim focus if the puzzle is finished
            if viewModel.finished {
                UIApplication.shared.endEditing()
                DispatchQueue.main.async { UIApplication.shared.endEditing() }
            }
        }
    }

    // MARK: - Header
    private var header: some View {
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

            Text("Diagone")
                .font(.headline)

            Spacer()

            if viewModel.started && !viewModel.isSolved {
                // In-progress: show timer + pause
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
            } else if viewModel.started && viewModel.isSolved {
                // Solved: show elapsed only
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


    // MARK: - Start / Resume / Completed Hub
    private var startHub: some View {
        VStack(spacing: 0) {

            VStack(spacing: 16) {
                Spacer()
                DiagoneIconView(size: 80)

                Text("Diagone")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Drag and drop diagonals to spell six horizontal words")
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
                        if viewModel.finished { viewModel.showMainInput = false }
                        DispatchQueue.main.async {
                            UIApplication.shared.endEditing()
                        }
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

    // MARK: - Chip Pane Layout
    //
    // Displays two rows of diagonal word chips (lengths 1-5).
    // Simple layout: all chips in a row with small gaps, vertically centered.
    // Math is straightforward and guaranteed to fit.

    /// Horizontal margin on each side of the chip pane, proportional to screen width
    private func chipPaneMargin(for width: CGFloat) -> CGFloat { width * 0.02 }

    /// Gap between adjacent chips, proportional to screen width
    private func chipGap(for width: CGFloat) -> CGFloat { width * 0.004 }

    /// Vertical spacing between the two chip rows, proportional to screen width
    private func chipRowSpacing(for width: CGFloat) -> CGFloat { width * 0.02 }

    /// Tile size as fraction of cellSize (must match ChipView)
    private let tileFactor: CGFloat = 0.85

    /// Step between diagonal tiles as fraction of tileSize (must match ChipView)
    private let stepFactor: CGFloat = 0.72

    // MARK: - Layout Calculation

    /// Computes the span factor for a chip of given length.
    /// span = cellSize * spanFactor(length)
    private func spanFactor(_ length: Int) -> CGFloat {
        // span(L) = (L-1) * step + tileSize
        //         = (L-1) * stepFactor * tileFactor * cellSize + tileFactor * cellSize
        //         = tileFactor * cellSize * (1 + stepFactor * (L-1))
        return tileFactor * (1 + stepFactor * CGFloat(length - 1))
    }

    /// Effective span factor for positioning: for chips with 2+ letters,
    /// we measure to the right edge of the 2nd letter (not the last letter)
    private func effectiveSpanFactor(_ length: Int) -> CGFloat {
        if length == 1 {
            // Only 1 letter, so edge is at tileSize
            return tileFactor
        } else {
            // Measure to right edge of 2nd letter: step + tileSize
            // = tileFactor * stepFactor * cellSize + tileFactor * cellSize
            // = tileFactor * (1 + stepFactor) * cellSize
            return tileFactor * (1 + stepFactor)
        }
    }

    /// Total width factor: sum of effective spans for chips 1-4, plus FULL span for chip 5
    /// This ensures the rightmost edge of chip 5 fits within availableWidth
    private var totalWidthFactor: CGFloat {
        // Chips 1-4 use effective span for positioning
        // Chip 5 uses full span since it's the last one and must fit entirely
        var sum: CGFloat = 0
        for L in 1...4 {
            sum += effectiveSpanFactor(L)
        }
        sum += spanFactor(5)  // Full span for last chip
        // Add a buffer (20%) to ensure comfortable fit
        return sum * 1.2
    }

    /// Computes cellSize that makes all chips fit exactly in availableWidth.
    private func computeCellSize(availableWidth: CGFloat, gap: CGFloat) -> CGFloat {
        let totalGaps = 4 * gap  // 4 gaps between 5 chips
        return (availableWidth - totalGaps) / totalWidthFactor
    }

    /// Actual span (width = height) for a chip of given length (full size)
    private func chipSpan(_ length: Int, cellSize: CGFloat) -> CGFloat {
        return cellSize * spanFactor(length)
    }

    /// Effective span used for positioning (to 2nd letter for chips with 2+ letters)
    private func effectiveSpan(_ length: Int, cellSize: CGFloat) -> CGFloat {
        return cellSize * effectiveSpanFactor(length)
    }

    /// Computes x-positions for all 5 chips, given cellSize
    /// Gap is measured from 2nd letter of current chip to 1st letter of next chip
    private func computeXPositions(cellSize: CGFloat, gap: CGFloat) -> [CGFloat] {
        var positions: [CGFloat] = []
        var x: CGFloat = 0
        for L in 1...5 {
            positions.append(x)
            // Advance by effective span (to 2nd letter for L>=2, or to end for L=1)
            x += effectiveSpan(L, cellSize: cellSize)
            if L < 5 {
                x += gap
            }
        }
        return positions
    }

    /// Computes vertical offset to center a chip within the row height
    private func chipYOffset(_ length: Int, cellSize: CGFloat, maxSpan: CGFloat) -> CGFloat {
        let span = chipSpan(length, cellSize: cellSize)
        return (maxSpan - span) / 2
    }

    // MARK: - Chip Pane View

    @ViewBuilder
    private func chipPane(width: CGFloat) -> some View {
        let margin = chipPaneMargin(for: width)
        let gap = chipGap(for: width)
        let rowSpacing = chipRowSpacing(for: width)
        let availableWidth = width - 2 * margin
        let cellSize = computeCellSize(availableWidth: availableWidth, gap: gap)
        let xPositions = computeXPositions(cellSize: cellSize, gap: gap)
        let maxSpan = chipSpan(5, cellSize: cellSize)  // Height of tallest chip

        // Group pieces by length
        let groups = Dictionary(grouping: viewModel.engine.state.pieces, by: \.length)
        let sortById = { (pieces: [GamePiece]) in
            pieces.sorted { lhs, rhs in
                let li = Int(lhs.id.drop(while: { !$0.isNumber })) ?? 0
                let ri = Int(rhs.id.drop(while: { !$0.isNumber })) ?? 0
                return li < ri
            }
        }

        // Randomized row assignment: chipRowAssignment[i] controls which piece of length i+1 goes in which row
        let row1: [GamePiece?] = (1...5).map { L in
            let sorted = groups[L].map(sortById)
            return chipRowAssignment[L - 1] ? sorted?.first : sorted?.dropFirst().first
        }
        let row2: [GamePiece?] = (1...5).map { L in
            let sorted = groups[L].map(sortById)
            return chipRowAssignment[L - 1] ? sorted?.dropFirst().first : sorted?.first
        }

        VStack(spacing: rowSpacing) {
            chipRow(pieces: row1, cellSize: cellSize, xPositions: xPositions,
                    maxSpan: maxSpan, rowWidth: availableWidth)
            chipRow(pieces: row2, cellSize: cellSize, xPositions: xPositions,
                    maxSpan: maxSpan, rowWidth: availableWidth)


        }
        .frame(width: availableWidth)
    }

    @ViewBuilder
    private func chipRow(
        pieces: [GamePiece?],
        cellSize: CGFloat,
        xPositions: [CGFloat],
        maxSpan: CGFloat,
        rowWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<5, id: \.self) { i in
                let length = i + 1
                let span = chipSpan(length, cellSize: cellSize)
                let xPos = xPositions[i]
                let yPos = chipYOffset(length, cellSize: cellSize, maxSpan: maxSpan)

                if let piece = pieces[i] {
                    ChipView(piece: piece, cellSize: cellSize, hidden: !viewModel.started)
                        .frame(width: span, height: span, alignment: .topLeading)
                        .offset(x: xPos, y: yPos)
                }
            }
        }
        .frame(width: rowWidth, height: maxSpan, alignment: .topLeading)
    }

    /// Helper to compute cellSize for the MainDiagonalInputView
    private func computeChipCellSize(totalWidth: CGFloat) -> CGFloat {
        let margin = chipPaneMargin(for: totalWidth)
        let gap = chipGap(for: totalWidth)
        return computeCellSize(availableWidth: totalWidth - 2 * margin, gap: gap)
    }


    // MARK: - Row Highlight Animation
    /// Starts the win highlight animation. Sequentially highlights each row of the
    private func startRowHighlightAnimation() {
        // Cancel any existing animation
        winHighlightTimer?.invalidate()
        highlightedRow = nil
        var row = 0
        winHighlightTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { timer in
            if row < 6 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    highlightedRow = row
                }
                row += 1
            } else {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    highlightedRow = nil
                }
                // After the win animation completes, show the completed hub
                UIApplication.shared.endEditing()
                showHub = true
            }
        }
    }
}

// MARK: - Floating Chip Overlay
/// Isolated view that tracks the drag position via a Combine subject so that
/// high-frequency position updates only invalidate this small overlay instead
/// of the entire DiagoneContentView tree.
private struct FloatingChipOverlay: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var location: CGPoint? = nil

    var body: some View {
        GeometryReader { proxy in
            if viewModel.dragSourceTargetId != nil,
               let pieceId = viewModel.draggingPieceId,
               let piece = viewModel.engine.state.pieces.first(where: { $0.id == pieceId }),
               let loc = location {
                let origin = proxy.frame(in: .global).origin
                let cellSize = proxy.size.width / 8.0
                let tileSize = cellSize * 0.85
                let step = tileSize * 0.85
                let span = step * CGFloat(piece.length - 1) + tileSize

                ZStack(alignment: .topLeading) {
                    ForEach(Array(piece.letters.enumerated()), id: \.offset) { index, ch in
                        Text(String(ch))
                            .font(.system(size: tileSize * 0.6, weight: .bold, design: .rounded))
                            .foregroundColor(.letter)
                            .frame(width: tileSize, height: tileSize)
                            .background(
                                RoundedRectangle(cornerRadius: tileSize * 0.15, style: .continuous)
                                    .fill(Color.boardCell)
                                    .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: tileSize * 0.15, style: .continuous)
                                    .stroke(Color.gridLine, lineWidth: 1)
                            )
                            .offset(x: CGFloat(index) * step, y: CGFloat(index) * step)
                    }
                }
                .frame(width: span, height: span)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                .position(
                    x: loc.x - origin.x - (viewModel.boardDragAnchorFraction.x - 0.5) * span,
                    y: loc.y - origin.y - (viewModel.boardDragAnchorFraction.y - 0.5) * span
                )
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onReceive(viewModel.dragPositionDidChange) {
            location = viewModel.dragGlobalLocation
        }
        .onChange(of: viewModel.dragSourceTargetId) { _, newValue in
            if newValue == nil {
                location = nil
            }
        }
    }
}
