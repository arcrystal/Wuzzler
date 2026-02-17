import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class TumblePunsViewModel: GameFlowViewModel {
    @Published public var wordAnswers: [String] = ["", "", "", ""]
    @Published public var finalAnswer: String = ""
    @Published public var selectedWordIndex: Int? = nil
    @Published public var isFinalAnswerSelected: Bool = false

    private(set) var engine: TumblePunsEngine

    override var winAnimationDuration: TimeInterval {
        let perLetter = 0.08
        // All words + final answer wave simultaneously; longest one determines duration
        let maxWordLen = engine.puzzle.words.map(\.solution.count).max() ?? 0
        let finalLetterCount = engine.puzzle.answerPattern.filter { $0 == "_" }.count
        let maxLen = max(maxWordLen, finalLetterCount)
        let lastDelay = 0.05 + perLetter * Double(max(maxLen - 1, 0))
        // + spring settle ~0.50s
        return lastDelay + 0.50
    }

    init(date: Date = Date()) {
        let puzzle = TumblePunsPuzzleLibrary.loadPuzzle(for: date)
        self.engine = TumblePunsEngine(puzzle: puzzle)
        super.init(storageKeyPrefix: "tumblepuns", gameType: .tumblePuns)

        // Restore game state if today's meta indicates we started today
        if started, let data = loadSavedState(),
           let savedState = try? JSONDecoder().decode(TumblePunsState.self, from: data) {
            self.engine = TumblePunsEngine(puzzle: puzzle, state: savedState)
            self.wordAnswers = savedState.wordAnswers
            self.finalAnswer = savedState.finalAnswer
            self.selectedWordIndex = savedState.selectedWordIndex
            self.isFinalAnswerSelected = savedState.isFinalAnswerSelected
        }
    }

    // MARK: - Template Method Overrides

    override func onStartGame() {
        wordAnswers = ["", "", "", ""]
        finalAnswer = ""
        selectedWordIndex = nil
        isFinalAnswerSelected = false
        engine = TumblePunsEngine(puzzle: engine.puzzle)
        selectWord(0)
    }

    override func onClearGame() {
        wordAnswers = ["", "", "", ""]
        finalAnswer = ""
        selectedWordIndex = nil
        isFinalAnswerSelected = false
        engine = TumblePunsEngine(puzzle: engine.puzzle)
    }

    override func onResume() {
        if selectedWordIndex == nil && !isFinalAnswerSelected {
            selectFirstIncompleteWord()
        }
    }

    override func checkGameSolved() -> Bool {
        let allWordsFilled = (0..<4).allSatisfy { i in
            wordAnswers[i].count >= engine.puzzle.words[i].solution.count
        }
        let expectedFinalLength = engine.puzzle.answerPattern.filter { $0 == "_" }.count
        let finalFilled = finalAnswer.count >= expectedFinalLength
        guard allWordsFilled && finalFilled else { return false }
        return engine.isSolved
    }

    override func onIncorrectAttempt() {
        engine.clearFinalAnswer()
        finalAnswer = engine.state.finalAnswer
        saveState()
    }

    override func encodeGameState() -> Data? {
        try? JSONEncoder().encode(engine.state)
    }

    override func restoreGameState(from data: Data) -> Bool {
        guard let state = try? JSONDecoder().decode(TumblePunsState.self, from: data) else { return false }
        engine = TumblePunsEngine(puzzle: engine.puzzle, state: state)
        wordAnswers = state.wordAnswers
        finalAnswer = state.finalAnswer
        selectedWordIndex = state.selectedWordIndex
        isFinalAnswerSelected = state.isFinalAnswerSelected
        return true
    }

    // MARK: - Game Actions

    func selectWord(_ index: Int?) {
        selectedWordIndex = index
        isFinalAnswerSelected = false
        engine.selectWord(index)
    }

    func selectFinalAnswer() {
        selectedWordIndex = nil
        isFinalAnswerSelected = true
        engine.selectFinalAnswer()
    }

    func typeKey(_ key: String) {
        engine.appendLetter(key)
        wordAnswers = engine.state.wordAnswers
        finalAnswer = engine.state.finalAnswer
        debouncedSave()
        checkAndSubmit()
        autoAdvanceAfterType()
    }

    func deleteKey() {
        engine.deleteLetter()
        wordAnswers = engine.state.wordAnswers
        finalAnswer = engine.state.finalAnswer
        debouncedSave()
        autoGoBackAfterDelete()
    }

    func clearWord(at index: Int) {
        engine.clearWord(at: index)
        wordAnswers = engine.state.wordAnswers
        selectWord(index)
        debouncedSave()
    }

    private func checkAndSubmit() {
        guard !finished else { return }
        let allWordsFilled = (0..<4).allSatisfy { i in
            wordAnswers[i].count >= engine.puzzle.words[i].solution.count
        }
        let expectedFinalLength = engine.puzzle.answerPattern.filter { $0 == "_" }.count
        let finalFilled = finalAnswer.count >= expectedFinalLength
        guard allWordsFilled && finalFilled else { return }
        submitAnswer()
    }

    private func selectFirstIncompleteWord() {
        for i in 0..<4 {
            if !correctWordIndices.contains(i) && wordAnswers[i].count < engine.puzzle.words[i].solution.count {
                selectWord(i)
                return
            }
        }
        let expectedFinalLength = engine.puzzle.answerPattern.filter { $0 == "_" }.count
        if finalAnswer.count < expectedFinalLength {
            selectFinalAnswer()
        }
    }

    private func autoAdvanceAfterType() {
        guard !finished else { return }
        if let idx = selectedWordIndex {
            let word = engine.puzzle.words[idx]
            if wordAnswers[idx].count >= word.solution.count {
                for next in (idx + 1)..<4 {
                    if !correctWordIndices.contains(next) && wordAnswers[next].count < engine.puzzle.words[next].solution.count {
                        selectWord(next)
                        return
                    }
                }
                let expectedFinalLength = engine.puzzle.answerPattern.filter { $0 == "_" }.count
                if finalAnswer.count < expectedFinalLength {
                    selectFinalAnswer()
                }
            }
        }
    }

    private func autoGoBackAfterDelete() {
        guard !finished else { return }
        if isFinalAnswerSelected && finalAnswer.isEmpty {
            for prev in stride(from: 3, through: 0, by: -1) {
                if !correctWordIndices.contains(prev) {
                    selectWord(prev)
                    return
                }
            }
        } else if let idx = selectedWordIndex, wordAnswers[idx].isEmpty {
            for prev in stride(from: idx - 1, through: 0, by: -1) {
                if !correctWordIndices.contains(prev) {
                    selectWord(prev)
                    return
                }
            }
        }
    }

    // MARK: - Computed Properties

    var correctWordIndices: Set<Int> {
        engine.correctWordIndices
    }

    var areWordsSolved: Bool {
        engine.areWordsSolved
    }

    var shadedLetters: String {
        engine.shadedLetters
    }

    var puzzle: TumblePunsPuzzle {
        engine.puzzle
    }
}
