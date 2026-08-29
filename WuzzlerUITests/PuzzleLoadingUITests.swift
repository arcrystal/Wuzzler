import XCTest

final class PuzzleLoadingUITests: XCTestCase {
    func testDiagoneShowsSharedLoadingTransition() {
        verifyLoadingTransition(
            cardIdentifier: "play-game-card-diagone",
            accessibilityPrefix: "diagone",
            gameElement: { $0.descendants(matching: .any)["diagone-board"] }
        )
    }

    func testRhymeAGramShowsSharedLoadingTransition() {
        verifyLoadingTransition(
            cardIdentifier: "play-game-card-rhymeAGrams",
            accessibilityPrefix: "rhymeagrams",
            gameElement: { $0.staticTexts["RhymeAGram"] }
        )
    }

    func testTumblePunShowsSharedLoadingTransition() {
        verifyLoadingTransition(
            cardIdentifier: "play-game-card-tumblePuns",
            accessibilityPrefix: "tumblepuns",
            gameElement: { $0.descendants(matching: .any)["tumble-words-grid"] }
        )
    }

    private func verifyLoadingTransition(
        cardIdentifier: String,
        accessibilityPrefix: String,
        gameElement: (XCUIApplication) -> XCUIElement
    ) {
        let app = XCUIApplication()
        app.launchArguments += [
            "-WuzzlerUITestAuthenticated",
            "-WuzzlerUITestResetState",
            "-WuzzlerUITestPuzzleLoadingMinimumDuration", "2.0",
            "-tutorial_seen_diagone", "YES",
            "-tutorial_seen_rhymeagrams", "YES",
            "-tutorial_seen_tumblepuns", "YES",
        ]
        app.launch()

        let playTab = app.descendants(matching: .any)["main-tab-play"]
        XCTAssertTrue(playTab.waitForExistence(timeout: 8))
        playTab.tap()

        let card = app.descendants(matching: .any)[cardIdentifier]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        if !card.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(card.isHittable)
        card.tap()

        let playButton = app.buttons["\(accessibilityPrefix)-start-button"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 4))
        playButton.tap()

        let loadingBar = app.descendants(matching: .any)["\(accessibilityPrefix)-start-progress"]
        XCTAssertTrue(loadingBar.waitForExistence(timeout: 2))

        XCTAssertTrue(gameElement(app).waitForExistence(timeout: 6))
    }
}
