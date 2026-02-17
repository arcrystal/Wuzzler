import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class GameViewModel: GameFlowViewModel {
    @Published private(set) var engine: GameEngine
    @Published public var dragHoverTargetId: String? = nil
    @Published public var showMainInput: Bool = false
    @Published public var showConfetti: Bool = false
    @Published public var mainInput: [String] = Array(repeating: "", count: 6)
    @Published public var draggingPieceId: String? = nil
    @Published public var fadingPanePieceIds: Set<String> = []
    @Published public var dragSourceTargetId: String? = nil

    var dragGlobalLocation: CGPoint? = nil
    var boardDragAnchorFraction: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var boardFrameGlobal: CGRect = .zero
    let dragPositionDidChange = PassthroughSubject<Void, Never>()

    private var winWaveTask: Task<Void, Never>?

    init(engine: GameEngine = GameEngine(puzzleDate: Date())) {
        self.engine = engine
        super.init(storageKeyPrefix: "diagone", gameType: .diagone)

        // Only restore board state if today's meta indicates we started today.
        if started, let restored = Self.loadSavedBoardState(for: engine.configuration) {
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
    }

    override func onClearGame() {
        winWaveTask?.cancel()
        showMainInput = false
        mainInput = Array(repeating: "", count: 6)
        showConfetti = false
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

    override func runWinSequence() {
        winWaveTask?.cancel()
        showConfetti = false

        let totalSteps = 11
        let perStep: Duration = .milliseconds(70)
        let tail: Duration = .milliseconds(420)

        winWaveTask = Task(priority: .userInitiated) { @MainActor in
            self.winWaveTrigger &+= 1

            let clock = ContinuousClock()
            try? await clock.sleep(for: perStep * (totalSteps - 1) + tail)

            Haptics.notify(.success)
            self.startConfettiSequence()
        }
    }

    /// Diagone uses a custom submit flow via maybeHandleCompletionState
    /// instead of the base submitAnswer(), because win effects include
    /// keyboard dismissal, showMainInput hiding, etc.
    private func triggerWinEffects() {
        finished = true
        finishTime = elapsedTime
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
        saveDailyMeta(started: true, finished: true, elapsedTime: elapsedTime, finishTime: finishTime)
        stopTimer()
        showMainInput = false

        winWaveTask?.cancel()
        showConfetti = false
        runWinSequence()
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

    // MARK: - Confetti Sequence

    private func startConfettiSequence() {
        withAnimation { self.showConfetti = true }
        let firstPause: TimeInterval = 1.1
        DispatchQueue.main.asyncAfter(deadline: .now() + firstPause) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.08)) { self.showConfetti = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                withAnimation { self?.showConfetti = true }
            }
        }
        let totalDuration: TimeInterval = 2.8
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            withAnimation { self?.showConfetti = false }
        }
    }

    // MARK: - Board Persistence

    private static func loadSavedBoardState(for configuration: PuzzleConfiguration) -> GameState? {
        guard let data = UserDefaults.standard.data(forKey: "diagone_state") else { return nil }
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

    private func clearMainDiagonal(hideInput: Bool = true) {
        let count = engine.state.mainDiagonal.cells.count
        let empty = Array(repeating: "", count: count)
        mainInput = empty
        if hideInput {
            showMainInput = false
        }
        engine.setMainDiagonal(empty)
        saveState()
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

    func removePiece(from targetId: String) {
        guard !finished else { return }
        guard let removedId = engine.removePiece(from: targetId) else { return }
        fadingPanePieceIds.remove(removedId)
        withAnimation(.easeInOut(duration: 0.1)) {
            clearMainDiagonal()
        }
        saveState()
        if finished {
            finished = false
            saveDailyMeta(finished: false)
        }
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
        let cell = side / 6.0
        let valid = Set(engine.validTargets(for: pid))

        func distanceToDiagonal(_ t: GameTarget, point: CGPoint) -> (distance: CGFloat, length: Int) {
            guard let first = t.cells.first, let last = t.cells.last else { return (.greatestFiniteMagnitude, t.length) }
            let a = CGPoint(x: (CGFloat(first.col) + 0.5) * cell, y: (CGFloat(first.row) + 0.5) * cell)
            let b = CGPoint(x: (CGFloat(last.col) + 0.5) * cell, y: (CGFloat(last.row) + 0.5) * cell)
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
                let box = CGRect(x: CGFloat(minC) * cell - cell * 0.25,
                                 y: CGFloat(minR) * cell - cell * 0.25,
                                 width: CGFloat(maxC - minC + 1) * cell + cell * 0.5,
                                 height: CGFloat(maxR - minR + 1) * cell + cell * 0.5)
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
            let boardCellSize = boardFrameGlobal.width / 6.0
            let pieceSize = CGFloat(target.length) * boardCellSize
            let pieceMinX = boardFrameGlobal.minX + CGFloat(startCell.col) * boardCellSize
            let pieceMinY = boardFrameGlobal.minY + CGFloat(startCell.row) * boardCellSize
            boardDragAnchorFraction = CGPoint(
                x: (fingerGlobal.x - pieceMinX) / pieceSize,
                y: (fingerGlobal.y - pieceMinY) / pieceSize
            )
        }

        _ = engine.removePiece(from: targetId)
        fadingPanePieceIds.insert(pieceId)
        clearMainDiagonal()
    }

    func isPaneChipInactive(_ pieceId: String) -> Bool {
        let placed = engine.state.pieces.first(where: { $0.id == pieceId })?.placedOn != nil
        return placed || fadingPanePieceIds.contains(pieceId)
    }

    // MARK: - Taps

    func handleTap(on targetId: String) {
        guard !finished else { return }
        Haptics.impact(.soft)
        removePiece(from: targetId)
    }

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
