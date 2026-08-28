import XCTest
@testable import Wuzzler

final class SecurityHardeningTests: XCTestCase {
    func testRemotePuzzleContentURLPolicyAllowsOnlyExpectedHTTPSManifest() throws {
        XCTAssertTrue(SecurityPolicy.isApprovedRemoteContentURL(SecurityPolicy.remotePuzzleContentURL))
        XCTAssertTrue(SecurityPolicy.isApprovedRemoteContentURL(try XCTUnwrap(URL(string: "https://arcrystal.github.io:443/Wuzzler/content/v1/puzzles.json"))))

        XCTAssertFalse(SecurityPolicy.isApprovedRemoteContentURL(try XCTUnwrap(URL(string: "http://arcrystal.github.io/Wuzzler/content/v1/puzzles.json"))))
        XCTAssertFalse(SecurityPolicy.isApprovedRemoteContentURL(try XCTUnwrap(URL(string: "https://evil.example/Wuzzler/content/v1/puzzles.json"))))
        XCTAssertFalse(SecurityPolicy.isApprovedRemoteContentURL(try XCTUnwrap(URL(string: "https://arcrystal.github.io/Wuzzler/content/v1/puzzles.json?debug=true"))))
        XCTAssertFalse(SecurityPolicy.isApprovedRemoteContentURL(try XCTUnwrap(URL(string: "https://arcrystal.github.io/Wuzzler/other.json"))))
        XCTAssertFalse(SecurityPolicy.isApprovedRemoteContentURL(try XCTUnwrap(URL(string: "https://user:pass@arcrystal.github.io/Wuzzler/content/v1/puzzles.json"))))
    }

    func testPuzzleManifestSizeIsBounded() {
        XCTAssertTrue(SecurityPolicy.isResponseSizeAllowed(SecurityPolicy.maximumPuzzleManifestBytes))
        XCTAssertFalse(SecurityPolicy.isResponseSizeAllowed(SecurityPolicy.maximumPuzzleManifestBytes + 1))
    }

    func testPuzzleManifestRequiresCurrentSchemaVersion() {
        var manifest = validManifest()
        XCTAssertTrue(PuzzleContentService.shared.validationFailures(for: manifest).isEmpty)

        manifest = PuzzleContentManifest(
            schemaVersion: 2,
            diagone: manifest.diagone,
            rhymeagrams: manifest.rhymeagrams,
            tumblepuns: manifest.tumblepuns
        )

        XCTAssertTrue(
            PuzzleContentService.shared
                .validationFailures(for: manifest)
                .contains(where: { $0.contains("schemaVersion") })
        )
    }

    func testPuzzleManifestRejectsUnsafeDisplayText() {
        let invalidTumblePuns = TumblePunsPuzzleLibrary.PuzzleData(
            words: validTumbleWords(),
            definition: "Bad\u{0000}clue",
            answerPattern: "___-_____",
            answer: "OLD-TIMER"
        )
        let manifest = PuzzleContentManifest(
            schemaVersion: 1,
            diagone: validManifest().diagone,
            rhymeagrams: validManifest().rhymeagrams,
            tumblepuns: ["06/01/2026": invalidTumblePuns]
        )

        XCTAssertTrue(
            PuzzleContentService.shared
                .validationFailures(for: manifest)
                .contains(where: { $0.contains("answer, or clue") })
        )
    }

    func testGeneratedInfoPlistDoesNotDisableATS() throws {
        let transportSecurity = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any]
        let allowsArbitraryLoads = transportSecurity?["NSAllowsArbitraryLoads"] as? Bool

        XCTAssertNotEqual(allowsArbitraryLoads, true)
    }

    func testReleaseFacingInfoPlistValues() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Wuzzler Daily")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool, false)
    }

    func testPrivacyManifestDeclaresNoTrackingOrCollectionAndApprovedDefaultsReason() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let manifest = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )

        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((manifest["NSPrivacyTrackingDomains"] as? [String])?.count, 0)
        XCTAssertEqual((manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])?.count, 0)

        let accessedTypes = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaultsDeclaration = try XCTUnwrap(
            accessedTypes.first(where: {
                $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
            })
        )
        XCTAssertEqual(defaultsDeclaration["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }

    private func validManifest() -> PuzzleContentManifest {
        PuzzleContentManifest(
            schemaVersion: 1,
            diagone: [
                "06/01/2026": ["MARKET", "ENERGY", "NATIVE", "FALCON", "ORANGE", "RETELL"]
            ],
            rhymeagrams: [
                "06/01/2026": RhymeAGramsPuzzleLibrary.PuzzleData(
                    letters: ["B", "EEE", "EHIII", "IKKKKLP"],
                    solutions: ["BIKE", "HIKE", "LIKE", "PIKE"]
                )
            ],
            tumblepuns: [
                "06/01/2026": TumblePunsPuzzleLibrary.PuzzleData(
                    words: validTumbleWords(),
                    definition: "A sundial",
                    answerPattern: "___-_____",
                    answer: "OLD-TIMER"
                )
            ]
        )
    }

    private func validTumbleWords() -> [TumblePunsPuzzleLibrary.PuzzleData.WordData] {
        [
            .init(scrambled: "DYTIZ", solution: "DITZY", shadedIndices: [2]),
            .init(scrambled: "DWONWI", solution: "WINDOW", shadedIndices: [4, 5]),
            .init(scrambled: "XEPPELR", solution: "PERPLEX", shadedIndices: [2, 5]),
            .init(scrambled: "AJIMYTOR", solution: "MAJORITY", shadedIndices: [1, 5, 7])
        ]
    }

}
