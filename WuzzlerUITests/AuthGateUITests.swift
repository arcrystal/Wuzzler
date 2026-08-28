import XCTest

final class AuthGateUITests: XCTestCase {
    func testGuestLaunchGoesDirectlyToPlay() {
        let app = guestApp()

        XCTAssertTrue(element("main-tab-play", in: app).waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Sign in with Game Center"].exists)
        XCTAssertTrue(element("play-game-card-diagone", in: app).exists)
        XCTAssertTrue(element("play-game-card-rhymeAGrams", in: app).exists)
        XCTAssertTrue(element("play-game-card-tumblePuns", in: app).exists)
    }

    func testGuestSocialDestinationsOfferSignInWithoutBlockingLocalProgress() {
        let app = guestApp()
        XCTAssertTrue(element("main-tab-play", in: app).waitForExistence(timeout: 8))

        element("main-tab-friends", in: app).tap()
        XCTAssertTrue(element("friends-sign-in", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(element("friends-audience-global", in: app).exists)

        element("main-tab-me", in: app).tap()
        XCTAssertTrue(app.staticTexts["Guest Player"].waitForExistence(timeout: 2))
        XCTAssertTrue(element("me-game-center", in: app).exists)
        XCTAssertTrue(element("me-statistics", in: app).exists)
    }

    func testAuthenticatedShellShowsThreeFloatingTabsAndGames() {
        let app = authenticatedApp()

        XCTAssertTrue(element("main-tab-play", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(element("main-tab-friends", in: app).exists)
        XCTAssertTrue(element("main-tab-me", in: app).exists)

        XCTAssertTrue(element("play-game-card-diagone", in: app).exists)
        XCTAssertTrue(element("play-game-card-rhymeAGrams", in: app).exists)
        XCTAssertTrue(element("play-game-card-tumblePuns", in: app).exists)
        XCTAssertTrue(element("play-archive-button", in: app).exists)
    }

    func testMeAndFriendsDestinationsAreReachable() {
        let app = authenticatedApp()
        XCTAssertTrue(element("main-tab-play", in: app).waitForExistence(timeout: 8))

        element("main-tab-me", in: app).tap()
        XCTAssertTrue(element("me-screen", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(element("me-statistics", in: app).exists)
        XCTAssertTrue(app.staticTexts["Personal Bests"].exists)
        XCTAssertFalse(app.staticTexts["Social"].exists)

        element("main-tab-friends", in: app).tap()
        XCTAssertTrue(element("friends-screen", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(element("friends-audience-friends", in: app).exists)
        XCTAssertTrue(element("friends-audience-global", in: app).exists)
        XCTAssertTrue(element("friends-board-wuzzler.sweep.daily", in: app).exists)
    }

    private func authenticatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-WuzzlerUITestAuthenticated", "-WuzzlerUITestResetState"]
        app.launch()
        return app
    }

    private func guestApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-WuzzlerUITestGuest", "-WuzzlerUITestResetState"]
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
