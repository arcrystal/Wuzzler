import XCTest
@testable import Wuzzler

final class ShareCardBuilderTests: XCTestCase {
    func testEveryShareCardLinksToPublishedWuzzlerSite() {
        let cards = [
            ShareCardBuilder.diagoneCard(time: 42, streakCount: 3),
            ShareCardBuilder.rhymeAGramsCard(time: 42, streakCount: 3),
            ShareCardBuilder.tumblePunsCard(
                wordLengths: [5, 6, 7, 8],
                shadedIndices: [[1], [2], [3], [4]],
                answerPattern: "___-_____",
                time: 42,
                streakCount: 3
            ),
        ]

        for card in cards {
            XCTAssertTrue(card.hasSuffix("https://arcrystal.github.io/Wuzzler/"))
            XCTAssertFalse(card.contains("wuzzler.app"))
        }
    }
}
