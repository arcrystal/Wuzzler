import SwiftUI

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Game-specific content for Diagone. Wrapped by GameFlowView in the coordinator.
struct DiagoneGameView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.gameAccent) private var gameAccent
    let onPause: () -> Void

    @State private var highlightedRow: Int? = nil
    @State private var winHighlightTimer: Timer? = nil
    @State private var chipRowAssignment: [Bool] = (0..<5).map { _ in Bool.random() }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            VStack(spacing: 0) {
                GameHeader(viewModel: viewModel, gameName: "Diagone", onPause: onPause)

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
                    // Keyboard (shown when all pieces placed, or game finished)
                    if viewModel.showMainInput || viewModel.finished {
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
                        .opacity(viewModel.finished ? 0.5 : 1.0)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.vertical)
                .animation(.easeInOut(duration: 0.3), value: viewModel.showMainInput)
            }
            .background(Color.boardCell.opacity(0.2).ignoresSafeArea())
            .onChange(of: viewModel.isSolved, initial: false) { oldValue, newValue in
                if newValue {
                    startRowHighlightAnimation()
                }
            }
            .overlay {
                FloatingChipOverlay()
                    .environmentObject(viewModel)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            UIApplication.shared.endEditing()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            UIApplication.shared.endEditing()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if viewModel.finished {
                UIApplication.shared.endEditing()
                DispatchQueue.main.async { UIApplication.shared.endEditing() }
            }
        }
        .environmentObject(viewModel)
    }

    // MARK: - Chip Pane Layout

    private func chipPaneMargin(for width: CGFloat) -> CGFloat { width * 0.02 }
    private func chipGap(for width: CGFloat) -> CGFloat { width * 0.004 }
    private func chipRowSpacing(for width: CGFloat) -> CGFloat { width * 0.02 }
    private let tileFactor: CGFloat = 0.85
    private let stepFactor: CGFloat = 0.72

    private func spanFactor(_ length: Int) -> CGFloat {
        tileFactor * (1 + stepFactor * CGFloat(length - 1))
    }

    private func effectiveSpanFactor(_ length: Int) -> CGFloat {
        if length == 1 {
            return tileFactor
        } else {
            return tileFactor * (1 + stepFactor)
        }
    }

    private var totalWidthFactor: CGFloat {
        var sum: CGFloat = 0
        for L in 1...4 {
            sum += effectiveSpanFactor(L)
        }
        sum += spanFactor(5)
        return sum * 1.2
    }

    private func computeCellSize(availableWidth: CGFloat, gap: CGFloat) -> CGFloat {
        let totalGaps = 4 * gap
        return (availableWidth - totalGaps) / totalWidthFactor
    }

    private func chipSpan(_ length: Int, cellSize: CGFloat) -> CGFloat {
        cellSize * spanFactor(length)
    }

    private func effectiveSpan(_ length: Int, cellSize: CGFloat) -> CGFloat {
        cellSize * effectiveSpanFactor(length)
    }

    private func computeXPositions(cellSize: CGFloat, gap: CGFloat) -> [CGFloat] {
        var positions: [CGFloat] = []
        var x: CGFloat = 0
        for L in 1...5 {
            positions.append(x)
            x += effectiveSpan(L, cellSize: cellSize)
            if L < 5 {
                x += gap
            }
        }
        return positions
    }

    private func chipYOffset(_ length: Int, cellSize: CGFloat, maxSpan: CGFloat) -> CGFloat {
        let span = chipSpan(length, cellSize: cellSize)
        return (maxSpan - span) / 2
    }

    @ViewBuilder
    private func chipPane(width: CGFloat) -> some View {
        let margin = chipPaneMargin(for: width)
        let gap = chipGap(for: width)
        let rowSpacing = chipRowSpacing(for: width)
        let availableWidth = width - 2 * margin
        let cellSize = computeCellSize(availableWidth: availableWidth, gap: gap)
        let xPositions = computeXPositions(cellSize: cellSize, gap: gap)
        let maxSpan = chipSpan(5, cellSize: cellSize)

        let groups = Dictionary(grouping: viewModel.engine.state.pieces, by: \.length)
        let sortById = { (pieces: [GamePiece]) in
            pieces.sorted { lhs, rhs in
                let li = Int(lhs.id.drop(while: { !$0.isNumber })) ?? 0
                let ri = Int(rhs.id.drop(while: { !$0.isNumber })) ?? 0
                return li < ri
            }
        }

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

    // MARK: - Row Highlight Animation
    private func startRowHighlightAnimation() {
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
            }
        }
    }
}

// MARK: - Floating Chip Overlay
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
