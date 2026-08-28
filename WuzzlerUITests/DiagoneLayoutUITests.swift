import XCTest

final class DiagoneLayoutUITests: XCTestCase {
    func testDiagoneChipsVisible() {
        let app = XCUIApplication()
        openDiagone(in: app)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "diagone-chip-layout-\(UIDevice.current.name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTappingPlacedDiagoneChipReturnsItToTray() {
        let app = XCUIApplication()
        openDiagone(in: app, launchArguments: ["-WuzzlerUITestPlaceDiagoneP1"])

        let board = app.otherElements["diagone-board"]
        let chip = app.descendants(matching: .any)["diagone-chip-p1"]
        XCTAssertTrue(board.waitForExistence(timeout: 4))
        XCTAssertTrue(chip.waitForValue("placed", timeout: 4))

        let topRightTarget = board.coordinate(withNormalizedOffset: CGVector(dx: 5.5 / 6.0, dy: 0.5 / 6.0))
        topRightTarget.tap()

        XCTAssertTrue(chip.waitForValue("available", timeout: 4))
        XCTAssertTrue(chip.isHittable)
    }

    private func openDiagone(in app: XCUIApplication, launchArguments: [String] = []) {
        app.launchArguments += [
            "-WuzzlerUITestResetState",
            "-WuzzlerUITestAuthenticated",
            "-tutorial_seen_diagone", "YES",
        ]
        app.launchArguments += launchArguments
        app.launch()

        let playTab = app.descendants(matching: .any)["main-tab-play"]
        _ = playTab.waitForExistence(timeout: 4)
        let diagoneCard = app.descendants(matching: .any)["play-game-card-diagone"]
        XCTAssertTrue(diagoneCard.waitForExistence(timeout: 8))
        diagoneCard.tap()

        let playButton = app.buttons["diagone-start-button"]
        let resumeButton = app.buttons["Resume"]
        if playButton.waitForExistence(timeout: 3) {
            playButton.tap()
            XCTAssertTrue(app.progressIndicators["diagone-start-progress"].exists)
        } else if resumeButton.waitForExistence(timeout: 3) {
            resumeButton.tap()
        } else {
            XCTAssertTrue(app.otherElements["diagone-chip-tray"].waitForExistence(timeout: 3))
        }

        XCTAssertTrue(app.otherElements["diagone-chip-tray"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.otherElements["diagone-board"].waitForExistence(timeout: 6))
    }
}

private extension XCUIElement {
    func waitForValue(_ expectedValue: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND value == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
