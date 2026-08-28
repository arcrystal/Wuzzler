import XCTest
@testable import Wuzzler

final class PuzzleDayTests: XCTestCase {
    func testUTCStorageAndPuzzleKeysAreStable() {
        let date = Date(timeIntervalSince1970: 1_780_272_000) // 2026-06-01T00:00:00Z

        XCTAssertEqual(PuzzleDay.storageKey(for: date), "2026-06-01")
        XCTAssertEqual(PuzzleDay.puzzleKey(for: date), "06/01/2026")
        XCTAssertEqual(PuzzleDay.leaderboardContext(for: date), 20260601)
    }

    func testUTCStartOfDayIgnoresLocalTimeZone() {
        let lateUTC = Date(timeIntervalSince1970: 1_780_358_399) // 2026-06-01T23:59:59Z
        let start = PuzzleDay.startOfDay(for: lateUTC)

        XCTAssertEqual(PuzzleDay.storageKey(for: start), "2026-06-01")
    }

    func testBundledLaunchDateContentExistsForEveryGame() throws {
        let launchDate = try XCTUnwrap(PuzzleDay.date(fromStorageKey: "2026-08-07"))

        for game in GameType.allCases {
            XCTAssertTrue(PuzzleContentService.shared.hasPuzzle(for: game, on: launchDate), "\(game.displayName) is missing launch-date content")
        }
    }
}
