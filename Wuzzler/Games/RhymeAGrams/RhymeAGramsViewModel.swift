import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class RhymeAGramsViewModel: GameFlowViewModel {
    @Published public var answers: [String] = ["", "", "", ""]
    @Published public var selectedSlot: Int = 0

    private(set) var engine: RhymeAGramsEngine

    override var winAnimationDuration: TimeInterval {
        // Last cell: row 3, letter 3 → delay = 0.05 + 0.22*3 + 0.09*3 = 0.98
        // + spring settle ~0.50s
        0.98 + 0.50
    }

    init(puzzleDate: Date = Date()) {
        let puzzle = RhymeAGramsPuzzleLibrary.loadPuzzle(for: puzzleDate)
        self.engine = RhymeAGramsEngine(puzzle: puzzle)
        super.init(storageKeyPrefix: "rhymeagrams", gameType: .rhymeAGrams, puzzleDate: puzzleDate)

        // Restore game state if meta indicates we started this puzzle
        if started, let data = loadSavedState(),
           let savedState = try? JSONDecoder().decode(RhymeAGramsState.self, from: data) {
            self.engine = RhymeAGramsEngine(puzzle: puzzle, state: savedState)
            self.answers = savedState.answers
            self.selectedSlot = savedState.selectedSlot
        }
    }

    // MARK: - Template Method Overrides

    override func onStartGame() {
        answers = ["", "", "", ""]
        selectedSlot = 0
        engine = RhymeAGramsEngine(puzzle: engine.puzzle)
    }

    override func onClearGame() {
        answers = ["", "", "", ""]
        selectedSlot = 0
        engine = RhymeAGramsEngine(puzzle: engine.puzzle)
    }

    override func onResume() {
        // No extra action needed
    }

    override func checkGameSolved() -> Bool {
        let allFilled = answers.allSatisfy { $0.count >= 4 }
        guard allFilled else { return false }
        return engine.isSolved
    }

    override func encodeGameState() -> Data? {
        try? JSONEncoder().encode(engine.state)
    }

    override func restoreGameState(from data: Data) -> Bool {
        guard let state = try? JSONDecoder().decode(RhymeAGramsState.self, from: data) else { return false }
        engine = RhymeAGramsEngine(puzzle: engine.puzzle, state: state)
        answers = state.answers
        selectedSlot = state.selectedSlot
        return true
    }

    // MARK: - Game Actions

    func selectSlot(_ index: Int) {
        selectedSlot = index
        engine.selectSlot(index)
    }

    func typeKey(_ key: String) {
        engine.appendLetter(key)
        answers = engine.state.answers
        debouncedSave()
        // Auto-advance to next unfilled slot when current word is full
        if answers[selectedSlot].count >= 4 {
            for i in 1...3 {
                let next = (selectedSlot + i) % 4
                if answers[next].count < 4 {
                    selectSlot(next)
                    break
                }
            }
        }
        checkAndSubmit()
    }

    func deleteKey() {
        // If current slot is empty, move to the previous non-empty slot
        if answers[selectedSlot].isEmpty {
            for i in 1...3 {
                let prev = (selectedSlot - i + 4) % 4
                if !answers[prev].isEmpty {
                    selectSlot(prev)
                    break
                }
            }
        }
        engine.deleteLetter()
        answers = engine.state.answers
        debouncedSave()
    }

    private func checkAndSubmit() {
        guard !finished else { return }
        let allFilled = answers.allSatisfy { $0.count >= 4 }
        guard allFilled else { return }
        submitAnswer()
    }

    // MARK: - Computed Properties

    var correctAnswerIndices: Set<Int> {
        engine.correctAnswerIndices
    }

    var puzzle: RhymeAGramsPuzzle {
        engine.puzzle
    }

    var usedPyramidPositions: [[Bool]] {
        var counts: [Character: Int] = [:]
        for answer in answers {
            for ch in answer {
                counts[ch, default: 0] += 1
            }
        }
        var result: [[Bool]] = []
        for row in puzzle.letters {
            var rowResult: [Bool] = []
            for ch in row {
                if let c = counts[ch], c > 0 {
                    counts[ch] = c - 1
                    rowResult.append(true)
                } else {
                    rowResult.append(false)
                }
            }
            result.append(rowResult)
        }
        return result
    }
}
