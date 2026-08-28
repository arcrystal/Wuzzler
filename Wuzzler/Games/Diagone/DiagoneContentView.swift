import SwiftUI

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
            let keyboardVisible = viewModel.showMainInput || viewModel.finished
            let chipPaneVisible = !viewModel.showMainInput && !viewModel.finished
            VStack(spacing: 0) {
                GameHeader(viewModel: viewModel, gameName: "Diagone", onPause: onPause)

                GeometryReader { contentGeo in
                    let layout = layout(
                        contentSize: contentGeo.size,
                        safeAreaBottom: geo.safeAreaInsets.bottom,
                        keyboardVisible: keyboardVisible,
                        chipPaneVisible: chipPaneVisible
                    )

                    VStack(spacing: layout.verticalSpacing) {
                        BoardView(highlightRow: highlightedRow)
                            .environmentObject(viewModel)
                            .frame(width: layout.boardSide, height: layout.boardSide)
                            .padding(.top, layout.topPadding)

                        Spacer(minLength: layout.minimumSpacer)

                        if chipPaneVisible {
                            chipTray(width: layout.controlWidth, safeAreaBottom: geo.safeAreaInsets.bottom)
                                .frame(width: layout.controlWidth)
                                .padding(.bottom, chipTrayScreenGutter(for: layout.controlWidth))
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if keyboardVisible {
                            KeyboardView(
                                onKeyTap: { key in
                                    viewModel.typeKey(key)
                                },
                                onDelete: {
                                    viewModel.deleteKey()
                                }
                            )
                            .padding(.horizontal)
                            .padding(.bottom, max(8, geo.safeAreaInsets.bottom + 4))
                            .frame(maxWidth: layout.controlWidth)
                            .opacity(viewModel.finished ? 0.5 : 1.0)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if viewModel.finished {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .environmentObject(viewModel)
        .onDisappear {
            winHighlightTimer?.invalidate()
            winHighlightTimer = nil
        }
    }

    // MARK: - Chip Pane Layout

    private struct Layout {
        let boardSide: CGFloat
        let controlWidth: CGFloat
        let topPadding: CGFloat
        let verticalSpacing: CGFloat
        let minimumSpacer: CGFloat
    }

    private func layout(
        contentSize: CGSize,
        safeAreaBottom: CGFloat,
        keyboardVisible: Bool,
        chipPaneVisible: Bool
    ) -> Layout {
        let horizontalPadding = max(16, min(32, contentSize.width * 0.055))
        let availableControlWidth = max(120, contentSize.width - horizontalPadding * 2)
        let maxControlWidth: CGFloat = contentSize.width > 700 ? 560 : 620
        let controlWidth = min(availableControlWidth, maxControlWidth)
        let availableBoardWidth = max(120, contentSize.width - horizontalPadding * 2)
        let maxBoardWidth = contentSize.width > 700 ? min(availableBoardWidth, 540) : availableBoardWidth
        let bottomReserve: CGFloat = {
            if keyboardVisible {
                return 166 + safeAreaBottom
            }
            if chipPaneVisible {
                return chipTrayHeight(for: controlWidth, safeAreaBottom: safeAreaBottom)
                    + chipTrayScreenGutter(for: controlWidth)
                    + 10
            }
            return 0
        }()
        let topPadding = max(8, min(18, contentSize.height * 0.025))
        let availableBoardHeight = max(120, contentSize.height - bottomReserve - topPadding - 18)
        let boardSide = max(120, min(maxBoardWidth, availableBoardHeight))
        let verticalSpacing = max(12, min(22, contentSize.height * 0.025))
        return Layout(
            boardSide: boardSide,
            controlWidth: controlWidth,
            topPadding: topPadding,
            verticalSpacing: verticalSpacing,
            minimumSpacer: max(8, verticalSpacing * 0.5)
        )
    }

    private func chipPaneMargin(for width: CGFloat) -> CGFloat { width * 0.02 }
    private func chipGap(for width: CGFloat) -> CGFloat { width * 0.004 }
    private func chipRowSpacing(for width: CGFloat) -> CGFloat { width * 0.02 }
    private func chipTrayHorizontalInset(for width: CGFloat) -> CGFloat { max(10, min(18, width * 0.035)) }
    private func chipTrayTopPadding(for width: CGFloat) -> CGFloat { max(10, min(16, width * 0.03)) }
    private func chipTrayBottomPadding(for width: CGFloat, safeAreaBottom: CGFloat) -> CGFloat {
        max(34, min(56, width * 0.095)) + safeAreaBottom
    }
    private func chipTrayScreenGutter(for width: CGFloat) -> CGFloat { max(12, min(24, width * 0.03)) }
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

    private func justifiedXPositions(cellSize: CGFloat, gap: CGFloat, rowWidth: CGFloat) -> [CGFloat] {
        let visualWidth = rowVisualWidth(cellSize: cellSize, gap: gap)
        let sideInset = max(14, min(26, cellSize * 0.6))
        let targetWidth = max(visualWidth, rowWidth - sideInset * 2)
        let extraGap = max(0, (targetWidth - visualWidth) / 4.0)
        let adjustedGap = gap + extraGap
        let adjustedWidth = rowVisualWidth(cellSize: cellSize, gap: adjustedGap)
        // Diagonal chips render down/right from their slot, so center with a little rightward overhang reserved.
        let renderedRightOverhang = cellSize * 1.35
        let leadingInset = max(0, (rowWidth - adjustedWidth - renderedRightOverhang) / 2.0)
        return computeXPositions(cellSize: cellSize, gap: adjustedGap).map { $0 + leadingInset }
    }

    private func rowVisualWidth(cellSize: CGFloat, gap: CGFloat) -> CGFloat {
        let xPositions = computeXPositions(cellSize: cellSize, gap: gap)
        return (1...5).reduce(CGFloat.zero) { width, length in
            max(width, xPositions[length - 1] + chipSpan(length, cellSize: cellSize))
        }
    }

    private func chipYOffset(_ length: Int, cellSize: CGFloat, maxSpan: CGFloat) -> CGFloat {
        let span = chipSpan(length, cellSize: cellSize)
        return (maxSpan - span) / 2
    }

    private func chipTrayHeight(for width: CGFloat, safeAreaBottom: CGFloat) -> CGFloat {
        let horizontalInset = chipTrayHorizontalInset(for: width)
        let contentWidth = max(120, width - horizontalInset * 2)
        return chipPaneHeight(for: contentWidth)
            + chipTrayTopPadding(for: width)
            + chipTrayBottomPadding(for: width, safeAreaBottom: safeAreaBottom)
    }

    private func chipPaneHeight(for width: CGFloat) -> CGFloat {
        let margin = chipPaneMargin(for: width)
        let gap = chipGap(for: width)
        let rowSpacing = chipRowSpacing(for: width)
        let availableWidth = width - 2 * margin
        let cellSize = computeCellSize(availableWidth: availableWidth, gap: gap)
        let maxSpan = chipSpan(5, cellSize: cellSize)
        return maxSpan * 2 + rowSpacing
    }

    @ViewBuilder
    private func chipTray(width: CGFloat, safeAreaBottom: CGFloat) -> some View {
        let horizontalInset = chipTrayHorizontalInset(for: width)
        let contentWidth = max(120, width - horizontalInset * 2)

        chipPane(width: contentWidth)
            .padding(.horizontal, horizontalInset)
            .padding(.top, chipTrayTopPadding(for: width))
            .padding(.bottom, chipTrayBottomPadding(for: width, safeAreaBottom: safeAreaBottom))
            .frame(width: width)
            .background(
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    Color.clear
                        .onAppear {
                            viewModel.chipTrayFrameGlobal = frame
                        }
                        .onChange(of: frame, initial: true) { _, newFrame in
                            viewModel.chipTrayFrameGlobal = newFrame
                        }
                }
            )
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.gridLine.opacity(0.55), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("diagone-chip-tray")
    }

    @ViewBuilder
    private func chipPane(width: CGFloat) -> some View {
        let margin = chipPaneMargin(for: width)
        let gap = chipGap(for: width)
        let rowSpacing = chipRowSpacing(for: width)
        let availableWidth = width - 2 * margin
        let cellSize = computeCellSize(availableWidth: availableWidth, gap: gap)
        let xPositions = justifiedXPositions(cellSize: cellSize, gap: gap, rowWidth: availableWidth)
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
