import XCTest
@testable import Wuzzler

@MainActor
final class RhymeAGramsKeyboardTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearRhymeAGramsDefaults()
    }

    override func tearDown() {
        clearRhymeAGramsDefaults()
        super.tearDown()
    }

    func testKeyboardAllowsLettersThatAreNotInPyramid() throws {
        let viewModel = try makeStartedViewModel()
        let pyramidLetters = Set(viewModel.puzzle.letters.joined().map { String($0) })
        let nonPuzzleLetter = try XCTUnwrap(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init).first { !pyramidLetters.contains($0) }
        )

        viewModel.typeKey(nonPuzzleLetter)

        XCTAssertEqual(viewModel.answers[0], nonPuzzleLetter)
    }

    func testKeyboardAllowsRepeatedPyramidLettersAfterInventoryWouldBeExhausted() throws {
        let viewModel = try makeStartedViewModel()
        let rareEntry = try XCTUnwrap(
            letterInventory(for: viewModel)
                .filter { $0.value < 4 }
                .min { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value < rhs.value }
                    return lhs.key < rhs.key
                }
        )
        let rarePuzzleLetter = rareEntry.key

        for _ in 0..<rareEntry.value {
            viewModel.typeKey(rarePuzzleLetter)
        }

        let answersAfterExhaustingLetter = viewModel.answers
        viewModel.typeKey(rarePuzzleLetter)

        XCTAssertNotEqual(viewModel.answers, answersAfterExhaustingLetter)
        XCTAssertEqual(viewModel.answers[0], String(repeating: rarePuzzleLetter, count: rareEntry.value + 1))
    }

    private func makeStartedViewModel() throws -> RhymeAGramsViewModel {
        let date = try XCTUnwrap(PuzzleDay.date(fromStorageKey: "2026-06-01"))
        let viewModel = RhymeAGramsViewModel(puzzleDate: date, countsTowardStats: false)
        viewModel.startGame()
        return viewModel
    }

    private func letterInventory(for viewModel: RhymeAGramsViewModel) -> [String: Int] {
        viewModel.puzzle.letters.joined().reduce(into: [:]) { counts, character in
            counts[String(character), default: 0] += 1
        }
    }

    private func clearRhymeAGramsDefaults() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("rhymeagrams") {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
