import XCTest

final class GUIRefreshUITests: XCTestCase {
    func testPlayCardsArchiveAndPracticeReturnFlow() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-WuzzlerUITestAuthenticated",
            "-WuzzlerUITestResetState",
            "-tutorial_seen_diagone", "YES"
        ]
        app.launch()

        let play = element("main-tab-play", in: app)
        XCTAssertTrue(play.waitForExistence(timeout: 8))

        for game in ["diagone", "rhymeAGrams", "tumblePuns"] {
            let card = element("play-game-card-\(game)", in: app)
            XCTAssertTrue(card.exists)
            XCTAssertTrue(card.label.contains("Play") || card.label.contains("Coming Soon"))
        }

        element("play-archive-button", in: app).tap()
        XCTAssertTrue(element("archive-screen", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("archive-game-diagone", in: app).exists)
        XCTAssertTrue(element("archive-game-rhymeAGrams", in: app).exists)
        XCTAssertTrue(element("archive-game-tumblePuns", in: app).exists)

        let yesterday = Self.utcDayKey(daysFromToday: -1)
        let archivedDate = element("archive-date-\(yesterday)", in: app)
        XCTAssertTrue(archivedDate.waitForExistence(timeout: 2))
        XCTAssertTrue(archivedDate.isEnabled)
        archivedDate.tap()

        let back = app.buttons["Back"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        back.tap()

        XCTAssertTrue(element("archive-screen", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("archive-game-diagone", in: app).isSelected)
        XCTAssertTrue(element("archive-date-\(yesterday)", in: app).exists)
    }

    func testFriendsControlsRemainTextBasedAndSelectable() {
        let app = XCUIApplication()
        app.launchArguments += ["-WuzzlerUITestAuthenticated", "-WuzzlerUITestResetState"]
        app.launch()

        let friendsTab = element("main-tab-friends", in: app)
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 8))
        friendsTab.tap()

        let global = element("friends-audience-global", in: app)
        XCTAssertTrue(global.waitForExistence(timeout: 3))
        global.tap()
        XCTAssertTrue(global.isSelected)

        let tumblePun = element("friends-board-wuzzler.tumblepuns.daily", in: app)
        XCTAssertTrue(tumblePun.waitForExistence(timeout: 2))
        tumblePun.tap()
        XCTAssertTrue(tumblePun.isSelected)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private static func utcDayKey(daysFromToday: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: Date())
        let date = calendar.date(byAdding: .day, value: daysFromToday, to: today)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
