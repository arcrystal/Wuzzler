import XCTest
@testable import Wuzzler

final class DailyProgressTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearProgressDefaults()
    }

    override func tearDown() {
        clearProgressDefaults()
        super.tearDown()
    }

    func testPracticeSolvesDoNotCountTowardDailyProgress() {
        writeMeta(prefix: "diagone_practice", day: PuzzleDay.today, finished: true, finishTime: 10, isPractice: true)

        XCTAssertFalse(StreakManager.todayProgress().diagoneCompleted)
        XCTAssertNil(StreakManager.finishTime(game: .diagone, on: PuzzleDay.today))

        writeMeta(prefix: "diagone", day: PuzzleDay.today, finished: true, finishTime: 12, isPractice: false)

        XCTAssertTrue(StreakManager.todayProgress().diagoneCompleted)
        XCTAssertEqual(StreakManager.finishTime(game: .diagone, on: PuzzleDay.today), 12)
    }

    func testPersonalBestIgnoresPracticeSolves() {
        let yesterday = PuzzleDay.addDays(-1, to: PuzzleDay.today)
        writeMeta(prefix: "diagone_practice", day: yesterday, finished: true, finishTime: 5, isPractice: true)
        writeMeta(prefix: "diagone", day: yesterday, finished: true, finishTime: 14, isPractice: false)
        writeMeta(prefix: "diagone", day: PuzzleDay.today, finished: true, finishTime: 10, isPractice: false)

        XCTAssertEqual(StreakManager.personalBestTime(game: .diagone), 10)
    }

    func testDailySweepRequiresAllThreeCountedSolves() {
        writeMeta(prefix: "diagone", day: PuzzleDay.today, finished: true, finishTime: 11, isPractice: false)
        writeMeta(prefix: "rhymeagrams", day: PuzzleDay.today, finished: true, finishTime: 13, isPractice: false)

        XCTAssertNil(StreakManager.dailySweepFinishTimes(on: PuzzleDay.today))

        writeMeta(prefix: "tumblepuns", day: PuzzleDay.today, finished: true, finishTime: 17, isPractice: false)

        let times = StreakManager.dailySweepFinishTimes(on: PuzzleDay.today)
        XCTAssertEqual(times?[.diagone], 11)
        XCTAssertEqual(times?[.rhymeAGrams], 13)
        XCTAssertEqual(times?[.tumblePuns], 17)
        XCTAssertEqual(times?.values.reduce(0, +), 41)
    }

    @MainActor
    func testScoreConversionUsesCentiseconds() {
        XCTAssertEqual(LeaderboardService.centiseconds(from: 12.345), 1235)
        XCTAssertEqual(LeaderboardService.centiseconds(from: 0), 0)
        XCTAssertEqual(LeaderboardService.centiseconds(from: -4), 0)
    }

    @MainActor
    func testQueuedScoresCoalesceByLeaderboardAndDayKeepingLowestScore() {
        let scores = [
            PendingLeaderboardScore(leaderboardID: WuzzlerLeaderboard.diagoneDaily.rawValue, score: 2400, context: 20260601, dayKey: "2026-06-01"),
            PendingLeaderboardScore(leaderboardID: WuzzlerLeaderboard.diagoneDaily.rawValue, score: 2200, context: 20260601, dayKey: "2026-06-01"),
            PendingLeaderboardScore(leaderboardID: WuzzlerLeaderboard.rhymeagramsDaily.rawValue, score: 1800, context: 20260601, dayKey: "2026-06-01"),
            PendingLeaderboardScore(leaderboardID: WuzzlerLeaderboard.diagoneDaily.rawValue, score: 2600, context: 20260602, dayKey: "2026-06-02")
        ]

        let coalesced = LeaderboardService.coalescedPendingScores(scores)

        XCTAssertEqual(coalesced.count, 3)
        XCTAssertTrue(coalesced.contains(PendingLeaderboardScore(leaderboardID: WuzzlerLeaderboard.diagoneDaily.rawValue, score: 2200, context: 20260601, dayKey: "2026-06-01")))
        XCTAssertTrue(coalesced.contains(PendingLeaderboardScore(leaderboardID: WuzzlerLeaderboard.rhymeagramsDaily.rawValue, score: 1800, context: 20260601, dayKey: "2026-06-01")))
        XCTAssertTrue(coalesced.contains(PendingLeaderboardScore(leaderboardID: WuzzlerLeaderboard.diagoneDaily.rawValue, score: 2600, context: 20260602, dayKey: "2026-06-02")))
    }

    @MainActor
    func testGuestScoreRemainsQueuedThenFlushesAfterAuthentication() async throws {
        let suiteName = "LeaderboardServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let pending = PendingLeaderboardScore(
            leaderboardID: WuzzlerLeaderboard.diagoneDaily.rawValue,
            score: 1234,
            context: 20260828,
            dayKey: "2026-08-28"
        )
        defaults.set(try JSONEncoder().encode([pending]), forKey: "game_center_pending_scores_v1")

        var isAuthenticated = false
        var submitted: [PendingLeaderboardScore] = []
        let service = LeaderboardService(
            defaults: defaults,
            authenticationProvider: { isAuthenticated },
            submitter: { score in
                submitted.append(score)
                return true
            }
        )

        await service.flushPendingSubmissions()
        XCTAssertTrue(submitted.isEmpty)
        XCTAssertFalse(try JSONDecoder().decode([PendingLeaderboardScore].self, from: defaults.data(forKey: "game_center_pending_scores_v1")!).isEmpty)

        isAuthenticated = true
        await service.flushPendingSubmissions()

        XCTAssertEqual(submitted, [pending])
        XCTAssertTrue(try JSONDecoder().decode([PendingLeaderboardScore].self, from: defaults.data(forKey: "game_center_pending_scores_v1")!).isEmpty)
        XCTAssertTrue(defaults.bool(forKey: "game_center_submitted_score_\(pending.leaderboardID)_\(pending.dayKey)"))
    }

    @MainActor
    func testGuestAchievementsRemainQueuedThenFlushAfterAuthentication() async throws {
        let suiteName = "AchievementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let pending = [WuzzlerAchievement.firstSolve.rawValue, WuzzlerAchievement.firstDiagone.rawValue]
        defaults.set(try JSONEncoder().encode(pending), forKey: "game_center_pending_achievements_v1")

        var isAuthenticated = false
        var reported: [[WuzzlerAchievement]] = []
        let service = AchievementService(
            defaults: defaults,
            authenticationProvider: { isAuthenticated },
            reporter: { achievements in
                reported.append(achievements)
                return true
            }
        )

        await service.flushPendingReports()
        XCTAssertTrue(reported.isEmpty)

        isAuthenticated = true
        await service.flushPendingReports()

        XCTAssertEqual(Set(reported.flatMap { $0 }), Set([.firstSolve, .firstDiagone]))
        XCTAssertTrue(try JSONDecoder().decode([String].self, from: defaults.data(forKey: "game_center_pending_achievements_v1")!).isEmpty)
        XCTAssertTrue(defaults.bool(forKey: "game_center_reported_achievement_\(WuzzlerAchievement.firstSolve.rawValue)"))
        XCTAssertTrue(defaults.bool(forKey: "game_center_reported_achievement_\(WuzzlerAchievement.firstDiagone.rawValue)"))
    }

    private func writeMeta(prefix: String, day: Date, finished: Bool, finishTime: TimeInterval, isPractice: Bool) {
        let meta = TestDailyMeta(
            started: true,
            finished: finished,
            elapsedTime: finishTime,
            finishTime: finishTime,
            lastUpdated: Date(),
            isPractice: isPractice
        )
        let key = "\(prefix)_meta_\(PuzzleDay.storageKey(for: day))"
        do {
            let data = try JSONEncoder().encode(meta)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            XCTFail("Failed to encode daily progress metadata: \(error)")
        }
    }

    private func clearProgressDefaults() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix("diagone") || key.hasPrefix("rhymeagrams") || key.hasPrefix("tumblepuns") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}

private struct TestDailyMeta: Codable {
    var started: Bool
    var finished: Bool
    var elapsedTime: TimeInterval
    var finishTime: TimeInterval
    var lastUpdated: Date
    var isPractice: Bool?
}
