import XCTest
@testable import Wuzzler

final class PuzzleArchiveTests: XCTestCase {
    private let fixtureKeys: Set<String> = [
        "01/31/2026",
        "02/13/2026",
        "02/14/2026",
        "02/16/2026",
        "03/01/2026"
    ]

    override func setUp() {
        super.setUp()
        clearFixtureProgress()
    }

    override func tearDown() {
        clearFixtureProgress()
        super.tearDown()
    }

    func testMonthGenerationUsesActualPuzzleDateBounds() throws {
        let today = try XCTUnwrap(PuzzleDay.date(fromStorageKey: "2026-02-15"))
        let months = PuzzleArchiveProvider.makeMonths(
            gameType: .diagone,
            availablePuzzleKeys: fixtureKeys,
            today: today
        )

        XCTAssertEqual(months.map(\.id), ["2026-01", "2026-02", "2026-03"])
        XCTAssertEqual(months.first?.days.first?.id, "2026-01-01")
        XCTAssertEqual(months.last?.days.last?.id, "2026-03-31")
    }

    func testMissingAndFutureDatesRemainDisabled() throws {
        let today = try XCTUnwrap(PuzzleDay.date(fromStorageKey: "2026-02-15"))
        let february = try XCTUnwrap(
            PuzzleArchiveProvider.makeMonths(
                gameType: .diagone,
                availablePuzzleKeys: fixtureKeys,
                today: today
            ).first(where: { $0.id == "2026-02" })
        )

        let missingToday = try XCTUnwrap(february.days.first(where: { $0.id == "2026-02-15" }))
        XCTAssertFalse(missingToday.hasPuzzle)
        XCTAssertFalse(missingToday.canLaunch)

        let future = try XCTUnwrap(february.days.first(where: { $0.id == "2026-02-16" }))
        XCTAssertTrue(future.hasPuzzle)
        XCTAssertTrue(future.isFuture)
        XCTAssertFalse(future.canLaunch)

        let availablePast = try XCTUnwrap(february.days.first(where: { $0.id == "2026-02-14" }))
        XCTAssertTrue(availablePast.hasPuzzle)
        XCTAssertFalse(availablePast.isFuture)
        XCTAssertTrue(availablePast.canLaunch)
    }

    func testArchiveMapsSavedProgressStates() throws {
        writeMeta(day: "2026-02-13", finished: true, finishTime: 42)
        writeMeta(day: "2026-02-14", finished: false, finishTime: 0)
        let today = try XCTUnwrap(PuzzleDay.date(fromStorageKey: "2026-02-15"))
        let february = try XCTUnwrap(
            PuzzleArchiveProvider.makeMonths(
                gameType: .diagone,
                availablePuzzleKeys: fixtureKeys,
                today: today
            ).first(where: { $0.id == "2026-02" })
        )

        let completed = try XCTUnwrap(february.days.first(where: { $0.id == "2026-02-13" }))
        if case .completed(let time) = completed.status {
            XCTAssertEqual(time, 42)
        } else {
            XCTFail("Expected completed archive status")
        }

        let inProgress = try XCTUnwrap(february.days.first(where: { $0.id == "2026-02-14" }))
        if case .inProgress = inProgress.status {
            // Expected.
        } else {
            XCTFail("Expected in-progress archive status")
        }
    }

    func testLaunchModesAreTypedForEveryGame() {
        let yesterday = PuzzleDay.addDays(-1, to: PuzzleDay.today)

        for game in GameType.allCases {
            let daily = GameLaunch.archive(game, date: PuzzleDay.today)
            XCTAssertEqual(daily.mode, .daily)
            XCTAssertTrue(daily.countsTowardStats)

            let practice = GameLaunch.archive(game, date: yesterday)
            XCTAssertEqual(practice.mode, .practice)
            XCTAssertFalse(practice.countsTowardStats)
        }
    }

    func testAllThreeGameLibrariesProduceArchives() {
        for game in GameType.allCases {
            let months = PuzzleArchiveProvider.archiveMonths(for: game)
            XCTAssertFalse(months.isEmpty, "\(game.displayName) should have an archive")
            XCTAssertTrue(months.flatMap(\.days).contains(where: \.hasPuzzle))
        }
    }

    private func writeMeta(day: String, finished: Bool, finishTime: TimeInterval) {
        let meta = ArchiveTestMeta(
            started: true,
            finished: finished,
            elapsedTime: finished ? finishTime : 17,
            finishTime: finishTime,
            lastUpdated: Date(),
            isPractice: false
        )
        let data = try? JSONEncoder().encode(meta)
        UserDefaults.standard.set(data, forKey: "diagone_meta_\(day)")
    }

    private func clearFixtureProgress() {
        for day in ["2026-02-13", "2026-02-14"] {
            UserDefaults.standard.removeObject(forKey: "diagone_meta_\(day)")
            UserDefaults.standard.removeObject(forKey: "diagone_practice_meta_\(day)")
        }
    }
}

private struct ArchiveTestMeta: Codable {
    let started: Bool
    let finished: Bool
    let elapsedTime: TimeInterval
    let finishTime: TimeInterval
    let lastUpdated: Date
    let isPractice: Bool
}
