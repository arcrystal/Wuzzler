import SwiftUI

private struct TileBounceState { var scale: CGFloat = 1.0 }

private struct BoardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// Renders the 6×6 game board. Displays individual cells with letters, highlights
/// for the main diagonal and drag feedback, and overlays drop targets on top of
/// the board grid. The board listens to the `GameViewModel` for state and
/// emits callbacks through drop delegates when pieces are dropped.
struct BoardView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.gameAccent) private var gameAccent
    /// Optional row index to highlight during the win animation. When non‑nil
    /// the specified row is tinted with the accent colour.
    var highlightRow: Int?
    

    var body: some View {
        GeometryReader { geo in
            let side: CGFloat = min(geo.size.width, geo.size.height)
            let gap: CGFloat = Self.gridGap(for: side)
            let cellSize: CGFloat = (side - gap * 5) / 6.0

            ZStack {
                // Grid + letters layer
                GridLayer(cellSize: cellSize, gap: gap, highlightRow: highlightRow)
                    .frame(width: side, height: side)
                    .background(boardFrameReporter)
                    .modifier(Shake(animatableData: CGFloat(viewModel.shakeTrigger)))

                // Targets overlay layer (drag hit areas for placed chips)
                TargetsOverlayLayer(cellSize: cellSize, gap: gap)
            }
            .frame(width: side, height: side)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Diagone board"))
            .accessibilityIdentifier("diagone-board")
            .contentShape(Rectangle())
            .highPriorityGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard let cell = Self.cell(at: value.location, cellSize: cellSize, gap: gap) else { return }
                        viewModel.handleTap(at: cell)
                    }
            )
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: BoardFrameKey.self,
                                           value: proxy.frame(in: .global))
                }
            )
            .onPreferenceChange(BoardFrameKey.self) { rect in
                if viewModel.boardFrameGlobal != rect {
                    viewModel.boardFrameGlobal = rect
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.showIncorrectFeedback {
                    IncorrectToastView()
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    static func gridGap(for side: CGFloat) -> CGFloat {
        max(2, min(4, side * 0.008))
    }

    static func cell(at location: CGPoint, cellSize: CGFloat, gap: CGFloat) -> Cell? {
        guard location.x >= 0, location.y >= 0 else { return nil }
        let pitch = cellSize + gap
        let col = Int(location.x / pitch)
        let row = Int(location.y / pitch)
        guard (0..<6).contains(row), (0..<6).contains(col) else { return nil }

        let xInCell = location.x - CGFloat(col) * pitch
        let yInCell = location.y - CGFloat(row) * pitch
        guard xInCell <= cellSize, yInCell <= cellSize else { return nil }

        return Cell(row: row, col: col)
    }

    private var boardFrameReporter: some View {
        GeometryReader { p in
            Color.clear
                .onAppear { viewModel.boardFrameGlobal = p.frame(in: .global) }
                .onChange(of: p.size, initial: true) { _, _ in
                    viewModel.boardFrameGlobal = p.frame(in: .global)
                }
        }
    }
}

fileprivate struct GridLayer: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.gameAccent) private var gameAccent
    let cellSize: CGFloat
    let gap: CGFloat
    let highlightRow: Int?
    
    @ViewBuilder
    private func makeCell(isMain: Bool,
                          isHover: Bool,
                          isHighlighted: Bool,
                          letter: String,
                          cellSize: CGFloat,
                          delay: Double) -> some View {
        let cornerRadius = cellSize * 0.12
        let baseRect = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isMain ? gameAccent : (isHighlighted ? gameAccent.opacity(0.18) : Color.boardCell))
        let stroked = baseRect
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Color.gridLine, lineWidth: 1))
        let withHover = stroked
            .overlay(
                Group {
                    if isHover {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.hoverHighlight).allowsHitTesting(false)
                    }
                }
            )
        let withText = withHover
            .overlay(
                Group {
                    if !letter.isEmpty {
                        Text(letter)
                            .font(.system(size: cellSize * 0.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.letter)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                }
            )
        let framed = withText
            .frame(width: cellSize, height: cellSize)
            .compositingGroup()

        framed
            .keyframeAnimator(initialValue: TileBounceState(), trigger: viewModel.winWaveTrigger) { content, state in
                content.scaleEffect(state.scale)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.0, duration: delay)
                    SpringKeyframe(1.2, duration: 0.18, spring: .init(response: 0.36, dampingRatio: 0.62))
                    SpringKeyframe(1.0,  duration: 0.32, spring: .init(response: 0.40, dampingRatio: 0.72))
                }
            }
    }


    var body: some View {
        
        let engine = viewModel.engine
        let board  = engine.state.board
        let mainCells = Set(engine.state.mainDiagonal.cells)
        let hoverCells: Set<Cell> = {
            if let tid = viewModel.dragHoverTargetId,
               let t = engine.state.targets.first(where: { $0.id == tid }) {
                return Set(t.cells)
            }
            return []
        }()

        return VStack(spacing: gap) {
            ForEach(0..<6, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(0..<6, id: \.self) { c in
                        let id = Cell(row: r, col: c)
                        // Precompute simple values to reduce expression complexity
                        let waveStep = r + c
                        let isMain = mainCells.contains(id)
                        let isHover = hoverCells.contains(id)
                        let isHighlighted = highlightRow == r
                        let letter = board[r][c]

                        // NEW: baseline + per-step
                        let baseDelay = 0.02    // 20ms so no tile has 0 delay
                        let stepDelay = 0.07
                        let delay = baseDelay + stepDelay * Double(waveStep)

                        makeCell(isMain: isMain,
                                 isHover: isHover,
                                 isHighlighted: isHighlighted,
                                 letter: letter,
                                 cellSize: cellSize,
                                 delay: delay)
                    }
                }
            }
        }
    }
}

fileprivate struct TargetsOverlayLayer: View {
    @EnvironmentObject private var viewModel: GameViewModel
    let cellSize: CGFloat
    let gap: CGFloat
    var body: some View {
        ZStack {
            ForEach(viewModel.engine.state.targets.sorted(by: { $0.length > $1.length }), id: \.id) { t in
                DropTargetOverlay(target: t, cellSize: cellSize, gap: gap)
                    .environmentObject(viewModel)
            }
        }
    }
}

/// A view representing an invisible drag area over an occupied diagonal. Taps are
/// resolved at the board level so empty target overlays never swallow them.
fileprivate struct DropTargetOverlay: View {
    let target: GameTarget
    let cellSize: CGFloat
    let gap: CGFloat
    @EnvironmentObject var viewModel: GameViewModel
    @State private var isDragging = false

    private var isOccupied: Bool {
        viewModel.engine.state.targets.first(where: { $0.id == target.id })?.pieceId != nil
    }

    var body: some View {
        // Calculate bounding box for the diagonal. All diagonals run from top‑left
        // to bottom‑right so width and height are equal to the number of cells.
        let start = target.cells.first!
        let length = CGFloat(target.length)
        let pitch = cellSize + gap
        let size = cellSize * length + gap * max(length - 1, 0)
        // Position the overlay so that its top‑left corner aligns with the
        // starting cell of the diagonal. `position` uses the centre point so we
        // add half the size to both coordinates.
        let centerX = pitch * CGFloat(start.col) + size / 2.0
        let centerY = pitch * CGFloat(start.row) + size / 2.0
        return Rectangle()
            .fill(Color.clear)
            .frame(width: size, height: size)
            .position(x: centerX, y: centerY)
            .contentShape({ () -> Path in
                let cellSize = self.cellSize
                let pitch = self.cellSize + self.gap
                let start = self.target.cells.first!
                var path = Path()
                for cell in target.cells {
                    let rect = CGRect(
                        x: CGFloat(cell.col - start.col) * pitch,
                        y: CGFloat(cell.row - start.row) * pitch,
                        width: cellSize,
                        height: cellSize
                    ).insetBy(dx: cellSize * 0.12, dy: cellSize * 0.12)
                    path.addRect(rect)
                }
                return path
            }())
            .zIndex(10)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .onChanged { value in
                        if isDragging {
                            viewModel.updateDrag(globalLocation: value.location)
                            return
                        }
                        guard isOccupied else { return }
                        isDragging = true
                        viewModel.beginDraggingFromBoard(targetId: target.id, fingerGlobal: value.location)
                        viewModel.updateDrag(globalLocation: value.location)
                    }
                    .onEnded { _ in
                        if isDragging {
                            viewModel.finishDrag()
                            isDragging = false
                        }
                    }
            )
            .allowsHitTesting(isOccupied || isDragging)
    }
}
