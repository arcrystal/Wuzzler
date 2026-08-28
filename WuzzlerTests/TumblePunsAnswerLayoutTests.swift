import XCTest
@testable import Wuzzler

final class TumblePunsAnswerLayoutTests: XCTestCase {
    func testLongSingleWordStaysOnOneLine() {
        let pattern = "______________"

        let rows = TumblePunsAnswerLayout.rows(for: pattern, maxColumns: 9)

        XCTAssertEqual(rows, [Array(0..<pattern.count)])
    }

    func testMultiWordAnswerBreaksOnlyAtWhitespace() {
        let pattern = "____ ______"

        let rows = TumblePunsAnswerLayout.rows(for: pattern, maxColumns: 8)

        XCTAssertEqual(rows, [Array(0..<4), Array(5..<11)])
    }

    func testWordsShareALineWhenTheyFit() {
        let pattern = "__ ____"

        let rows = TumblePunsAnswerLayout.rows(for: pattern, maxColumns: 7)

        XCTAssertEqual(rows, [Array(0..<7)])
    }

    func testHyphenatedAnswerStaysOnOneLine() {
        let pattern = "___-_____"

        let rows = TumblePunsAnswerLayout.rows(for: pattern, maxColumns: 5)

        XCTAssertEqual(rows, [Array(0..<9)])
    }
}
