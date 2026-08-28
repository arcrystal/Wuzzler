import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class GameViewModel: GameFlowViewModel {
    @Published private(set) var engine: GameEngine
    @Published public var dragHoverTargetId: String? = nil
    @Published public var showMainInput: Bool = false
    @Published public var mainInput: [String] = Array(repeating: "", count: 6)
    @Published public var draggingPieceId: String? = nil
    @Published public var fadingPanePieceIds: Set<String> = []
    @Published public var dragSourceTargetId: String? = nil

    var dragGlobalLocation: CGPoint? = nil
    var boardDragAnchorFraction: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var boardFrameGlobal: CGRect = .zero
    var chipTrayFrameGlobal: CGRect = .zero
    let dragPositionDidChange = PassthroughSubject<Void, Never>()

    private var engineStateCancellable: AnyCancellable?
    private var winWaveTask: Task<Void, Never>?

    init(puzzleDate: Date = Date(), countsTowardStats: Bool? = nil) {
        let engine = GameEngine(puzzleDate: puzzleDate)
        self.engine = engine
        super.init(storageKeyPrefix: "diagone", gameType: .diagone, puzzleDate: puzzleDate, countsTowardStats: countsTowardStats)
        engineStateCancellable = engine.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        // Only restore board state if meta indicates we started this puzzle.
        if started, let restored = Self.loadSavedBoardState(for: engine.configuration, storageKey: storageKey) {
            engine.restore(restored)
            let allPlaced = engine.state.targets.allSatisfy { $0.pieceId != nil }
            self.showMainInput = allPlaced
            self.mainInput = engine.state.mainDiagonal.value
        } else {
            engine.reset()
            self.showMainInput = false
            self.mainInput = Array(repeating: "", count: 6)
        }
    }

    // MARK: - Template Method Overrides

    override func onStartGame() {
        showMainInput = false
        engine.reset()
        mainInput = Array(repeating: "", count: 6)
#if DEBUG
        seedUITestPlacementIfNeeded()
#endif
    }

    override func onClearGame() {
        winWaveTask?.cancel()
        showMainInput = false
        mainInput = Array(repeating: "", count: 6)
        fadingPanePieceIds = []
        draggingPieceId = nil
        dragHoverTargetId = nil
        engine.reset()
    }

    override func onPause() {
        // Diagone pause just needs timer stopped (handled by base) and state saved
    }

    override func checkGameSolved() -> Bool {
        let allPlaced = engine.state.targets.allSatisfy { $0.pieceId != nil }
        let mainFilled = engine.state.mainDiagonal.value.allSatisfy { !$0.isEmpty }
        guard allPlaced && mainFilled else { return false }
        return engine.state.solved
    }

    override func encodeGameState() -> Data? {
        try? JSONEncoder().encode(engine.state)
    }

    override func restoreGameState(from data: Data) -> Bool {
        guard let state = try? JSONDecoder().decode(GameState.self, from: data) else { return false }
        engine.restore(state)
        return true
    }

    // MARK: - Diagone-Specific Win Sequence

    /// 11 wave steps × 70ms + 200ms tail = 900ms to last bounce peak.
    override var hapticDelay: TimeInterval { 0.07 * 10 + 0.2 }

    override func runWinSequence() {
        winWaveTask?.cancel()

        winWaveTask = Task(priority: .userInitiated) { @MainActor in
            self.winWaveTrigger &+= 1

            let clock = ContinuousClock()
            try? await clock.sleep(for: .milliseconds(Int(self.hapticDelay * 1000)))

            Haptics.notify(.success)
        }
    }

    /// Diagone uses a custom submit flow via maybeHandleCompletionState
    /// instead of the base submitAnswer(), because win effects include
    /// keyboard dismissal, showMainInput hiding, etc.
    private func triggerWinEffects() {
        // Set minimal state and start the animation immediately —
        // identical to the "View This Puzzle" replay path.
        finished = true
        finishTime = elapsedTime
        stopTimer()
        showMainInput = false
        runWinSequence()

        // Defer expensive work (keyboard, persistence) so it doesn't
        // block the first frames of the win animation.
        DispatchQueue.main.async { [self] in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
            saveDailyMeta(started: true, finished: true, elapsedTime: elapsedTime, finishTime: finishTime)
            saveState()
        }
    }

    private func triggerDiagoneIncorrectFeedback() {
        triggerIncorrectFeedback()
        clearMainDiagonal(hideInput: false)
    }

    /// Call after any state change that might complete the puzzle.
    private func maybeHandleCompletionState() {
        let allPlaced = engine.state.targets.allSatisfy { $0.pieceId != nil }
        let mainFilled = engine.state.mainDiagonal.value.allSatisfy { !$0.isEmpty }
        guard allPlaced && mainFilled else { return }
        if engine.state.solved {
            triggerWinEffects()
        } else {
            triggerDiagoneIncorrectFeedback()
        }
    }

    deinit {
        winWaveTask?.cancel()
    }

    // MARK: - Board Persistence

    private static func loadSavedBoardState(for configuration: PuzzleConfiguration, storageKey: String) -> GameState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        do {
            let state = try JSONDecoder().decode(GameState.self, from: data)
            if state.targets.count == configuration.diagonals.count - 1 && state.pieces.count == configuration.pieceLetters.count {
                return state
            }
        } catch {
            return nil
        }
        return nil
    }

    // MARK: - Main Diagonal

    private func clearMainDiagonal(hideInput: Bool = true, persist: Bool = true) {
        let count = engine.state.mainDiagonal.cells.count
        let empty = Array(repeating: "", count: count)
        mainInput = empty
        if hideInput {
            showMainInput = false
        }
        engine.setMainDiagonal(empty)
        if persist {
            saveState()
        }
    }

    func commitMainInput() {
        guard !finished else { return }
        var letters: [String] = []
        for ch in mainInput {
            if let first = ch.uppercased().first {
                letters.append(String(first))
            } else {
                letters.append("")
            }
        }
        engine.setMainDiagonal(letters)
        saveState()
        saveDailyMeta(elapsedTime: elapsedTime)
        maybeHandleCompletionState()
    }

    // MARK: - Piece Placement

    var isSolved: Bool {
        engine.state.solved
    }

    func validTargets(for pieceId: String) -> [String] {
        engine.validTargets(for: pieceId)
    }

    @discardableResult
    func handleDrop(pieceId: String, onto targetId: String) -> Bool {
        guard !finished else { return false }
        let (success, replacedId) = engine.placeOrReplace(pieceId: pieceId, on: targetId)
        if success {
            fadingPanePieceIds.insert(pieceId)
            if let rid = replacedId { fadingPanePieceIds.remove(rid) }
            if engine.state.targets.allSatisfy({ $0.pieceId != nil }) {
                withAnimation { showMainInput = true }
            }
            saveState()
            maybeHandleCompletionState()
        } else {
            Haptics.notify(.error)
        }
        return success
    }

    @discardableResult
    func removePiece(from targetId: String) -> Bool {
        guard !finished else { return false }
        guard let removedId = engine.removePiece(from: targetId) else { return false }
        fadingPanePieceIds.remove(removedId)
        withAnimation(.easeInOut(duration: 0.1)) {
            clearMainDiagonal(persist: false)
        }
        // Coalesce encoding and UserDefaults I/O after the visual state change.
        // pause() still flushes immediately, so this cannot lose progress when
        // the player leaves the game before the debounce fires.
        debouncedSave()
        return true
    }

    // MARK: - Drag Hooks

    func dragEntered(targetId: String) {
        dragHoverTargetId = targetId
    }

    func dragExited(targetId: String) {
        if dragHoverTargetId == targetId {
            dragHoverTargetId = nil
        }
    }

    @MainActor
    func beginDragging(pieceId: String) {
        guard !finished else { return }
        draggingPieceId = pieceId
        dragHoverTargetId = nil
    }

    func endDragging() {
        draggingPieceId = nil
        dragHoverTargetId = nil
    }

    @MainActor
    func updateDrag(globalLocation: CGPoint) {
        dragGlobalLocation = globalLocation
        dragPositionDidChange.send()
        guard !finished, let pid = draggingPieceId, boardFrameGlobal != .zero else {
            if dragHoverTargetId != nil { dragHoverTargetId = nil }
            return
        }
        let p = CGPoint(x: globalLocation.x - boardFrameGlobal.minX,
                        y: globalLocation.y - boardFrameGlobal.minY)
        let side = min(boardFrameGlobal.size.width, boardFrameGlobal.size.height)
        let gap = BoardView.gridGap(for: side)
        let cell = (side - gap * 5.0) / 6.0
        let pitch = cell + gap
        let valid = Set(engine.validTargets(for: pid))

        func distanceToDiagonal(_ t: GameTarget, point: CGPoint) -> (distance: CGFloat, length: Int) {
            guard let first = t.cells.first, let last = t.cells.last else { return (.greatestFiniteMagnitude, t.length) }
            let a = CGPoint(x: CGFloat(first.col) * pitch + cell / 2.0,
                            y: CGFloat(first.row) * pitch + cell / 2.0)
            let b = CGPoint(x: CGFloat(last.col) * pitch + cell / 2.0,
                            y: CGFloat(last.row) * pitch + cell / 2.0)
            let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let ap = CGPoint(x: point.x - a.x, y: point.y - a.y)
            let abLen2 = max(ab.x*ab.x + ab.y*ab.y, 0.0001)
            var tParam = (ap.x*ab.x + ap.y*ab.y) / abLen2
            tParam = min(max(tParam, 0.0), 1.0)
            let proj = CGPoint(x: a.x + ab.x * tParam, y: a.y + ab.y * tParam)
            let dx = point.x - proj.x
            let dy = point.y - proj.y
            return (sqrt(dx*dx + dy*dy), t.length)
        }

        var bestId: String? = nil
        var bestDist: CGFloat = .greatestFiniteMagnitude

        for t in engine.state.targets where valid.contains(t.id) {
            let (dist, len) = distanceToDiagonal(t, point: p)
            let radius = cell * (0.48 - 0.018 * CGFloat(len - 1))
            let rows = t.cells.map(\.row)
            let cols = t.cells.map(\.col)
            if let minR = rows.min(), let maxR = rows.max(), let minC = cols.min(), let maxC = cols.max() {
                let box = CGRect(x: CGFloat(minC) * pitch - cell * 0.25,
                                 y: CGFloat(minR) * pitch - cell * 0.25,
                                 width: CGFloat(maxC - minC) * pitch + cell * 1.5,
                                 height: CGFloat(maxR - minR) * pitch + cell * 1.5)
                guard box.contains(p) else { continue }
            }
            guard dist <= radius else { continue }
            if dist < bestDist { bestDist = dist; bestId = t.id }
        }

        if dragHoverTargetId != bestId {
            dragHoverTargetId = bestId
        }
    }

    @MainActor
    func finishDrag() {
        guard !finished else { return }
        let sourceTarget = dragSourceTargetId
        let releaseLocation = dragGlobalLocation
        defer {
            draggingPieceId = nil
            dragHoverTargetId = nil
            dragSourceTargetId = nil
            dragGlobalLocation = nil
            boardDragAnchorFraction = CGPoint(x: 0.5, y: 0.5)
        }
        guard let pid = draggingPieceId else { return }

        if let tid = dragHoverTargetId {
            let (success, replacedId) = engine.placeOrReplace(pieceId: pid, on: tid)
            if success {
                fadingPanePieceIds.insert(pid)
                if let rid = replacedId { fadingPanePieceIds.remove(rid) }
                if engine.state.targets.allSatisfy({ $0.pieceId != nil }) {
                    withAnimation { showMainInput = true }
                }
                saveState()
                maybeHandleCompletionState()
                return
            }
        }

        if let src = sourceTarget {
            if isDropInChipTray(releaseLocation) {
                fadingPanePieceIds.remove(pid)
                clearMainDiagonal(persist: false)
                debouncedSave()
                Haptics.impactAfterUIUpdate(.soft)
                return
            }

            let (ok, _) = engine.placeOrReplace(pieceId: pid, on: src)
            if ok {
                fadingPanePieceIds.insert(pid)
                if engine.state.targets.allSatisfy({ $0.pieceId != nil }) {
                    withAnimation { showMainInput = true }
                }
                saveState()
            } else {
                fadingPanePieceIds.remove(pid)
            }
        }
    }

    @MainActor
    func beginDraggingFromBoard(targetId: String, fingerGlobal: CGPoint) {
        guard !finished else { return }
        guard let target = engine.state.targets.first(where: { $0.id == targetId }),
              let pieceId = target.pieceId else { return }

        dragSourceTargetId = targetId
        draggingPieceId = pieceId
        dragHoverTargetId = nil

        if let startCell = target.cells.first, boardFrameGlobal != .zero {
            let side = min(boardFrameGlobal.width, boardFrameGlobal.height)
            let gap = BoardView.gridGap(for: side)
            let boardCellSize = (side - gap * 5.0) / 6.0
            let pitch = boardCellSize + gap
            let pieceSize = CGFloat(target.length) * boardCellSize + CGFloat(max(target.length - 1, 0)) * gap
            let pieceMinX = boardFrameGlobal.minX + CGFloat(startCell.col) * pitch
            let pieceMinY = boardFrameGlobal.minY + CGFloat(startCell.row) * pitch
            boardDragAnchorFraction = CGPoint(
                x: (fingerGlobal.x - pieceMinX) / pieceSize,
                y: (fingerGlobal.y - pieceMinY) / pieceSize
            )
        }

        _ = engine.removePiece(from: targetId)
        fadingPanePieceIds.insert(pieceId)
        clearMainDiagonal(persist: false)
        debouncedSave()
    }

    private func isDropInChipTray(_ point: CGPoint?) -> Bool {
        guard let point, chipTrayFrameGlobal != .zero else { return false }
        return chipTrayFrameGlobal.insetBy(dx: -24, dy: -24).contains(point)
    }

    func isPaneChipInactive(_ pieceId: String) -> Bool {
        let placed = engine.state.pieces.first(where: { $0.id == pieceId })?.placedOn != nil
        return placed || fadingPanePieceIds.contains(pieceId)
    }

    // MARK: - Taps

    func handleTap(on targetId: String) {
        guard !finished else { return }
        guard removePiece(from: targetId) else { return }
        Haptics.impactAfterUIUpdate(.soft)
    }

    func handleTap(at cell: Cell) {
        guard !finished else { return }
        guard let targetId = engine.occupiedTargetId(containing: cell) else { return }
        handleTap(on: targetId)
    }

#if DEBUG
    private func seedUITestPlacementIfNeeded() {
        guard SecurityPolicy.shouldSeedDiagoneUITestPiece else { return }
        _ = handleDrop(pieceId: "p1", onto: "d_len1_a")
    }
#endif

    // MARK: - Keyboard Input

    func typeKey(_ key: String) {
        guard !finished else { return }
        let up = key.uppercased()
        if let idx = mainInput.firstIndex(where: { $0.isEmpty }) {
            mainInput[idx] = up
        }
        commitMainInput()
    }

    func deleteKey() {
        guard !finished else { return }
        if let idx = (0..<mainInput.count).reversed().first(where: { !mainInput[$0].isEmpty }) {
            mainInput[idx] = ""
            commitMainInput()
        }
    }

    // MARK: - Overridden elapsedTimeString (Diagone shows finishTime when finished)

    override var elapsedTimeString: String {
        if finished {
            let minutes = Int(finishTime) / 60
            let seconds = Int(finishTime) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
