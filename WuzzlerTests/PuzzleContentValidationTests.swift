import XCTest
@testable import Wuzzler

final class PuzzleContentValidationTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testValidManifestHasNoValidationFailures() {
        let failures = PuzzleContentService.shared.validationFailures(for: validManifest())

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testRhymeAGramsValidationRejectsLetterInventoryMismatch() {
        var manifest = validManifest()
        manifest = PuzzleContentManifest(
            schemaVersion: manifest.schemaVersion,
            diagone: manifest.diagone,
            rhymeagrams: [
                "06/01/2026": .init(
                    letters: ["G", "AFN", "SAAEE", "EEAMMMZ"],
                    solutions: ["GAME", "FAME", "NAME", "SAME"]
                )
            ],
            tumblepuns: manifest.tumblepuns
        )

        let failures = PuzzleContentService.shared.validationFailures(for: manifest)

        XCTAssertTrue(failures.contains { $0.contains("displayed letters do not match") })
    }

    func testTumblePunsValidationRejectsBadShadedLetters() {
        var manifest = validManifest()
        manifest = PuzzleContentManifest(
            schemaVersion: manifest.schemaVersion,
            diagone: manifest.diagone,
            rhymeagrams: manifest.rhymeagrams,
            tumblepuns: [
                "06/01/2026": .init(
                    words: [
                        .init(scrambled: "ONEST", solution: "STONE", shadedIndices: [1]),
                        .init(scrambled: "NOMEL", solution: "LEMON", shadedIndices: [2]),
                        .init(scrambled: "HCNIP", solution: "PINCH", shadedIndices: [2]),
                        .init(scrambled: "LNIAS", solution: "SNAIL", shadedIndices: [1, 2])
                    ],
                    definition: "A match with love on the court",
                    answerPattern: "______",
                    answer: "TENNIS"
                )
            ]
        )

        let failures = PuzzleContentService.shared.validationFailures(for: manifest)

        XCTAssertTrue(failures.contains { $0.contains("shaded letters do not match") })
    }

    func testServiceUsesBundledManifestWhenRemoteCacheIsEmpty() throws {
        let service = PuzzleContentService(cacheURL: temporaryCacheURL())
        let launchDate = try XCTUnwrap(PuzzleDay.date(fromStorageKey: "2026-08-07"))

        for game in GameType.allCases {
            XCTAssertTrue(service.hasPuzzle(for: game, on: launchDate), "\(game.displayName) is missing bundled launch-date content")
        }
    }

    func testPartialCachedManifestMergesOverBundledContent() throws {
        let cacheURL = temporaryCacheURL()
        let remoteOnlyKey = "12/31/2026"
        let cachedManifest = """
        {
          "schemaVersion": 1,
          "diagone": {
            "\(remoteOnlyKey)": ["MARKET", "ENERGY", "NATIVE", "FALCON", "ORANGE", "RETELL"]
          },
          "rhymeagrams": {},
          "tumblepuns": {}
        }
        """
        try cachedManifest.data(using: .utf8)?.write(to: cacheURL, options: .atomic)

        let service = PuzzleContentService(cacheURL: cacheURL)
        let manifest = try XCTUnwrap(service.manifest())

        XCTAssertNotNil(manifest.diagone[remoteOnlyKey])
        XCTAssertNotNil(manifest.diagone["08/07/2026"])
        XCTAssertNotNil(manifest.rhymeagrams["08/07/2026"])
        XCTAssertNotNil(manifest.tumblepuns["08/07/2026"])
    }

    func testValidRemoteManifestIsCachedAndMerged() async throws {
        let cacheURL = temporaryCacheURL()
        let remoteOnlyKey = "12/31/2026"
        let payload = """
        {
          "schemaVersion": 1,
          "diagone": {
            "\(remoteOnlyKey)": ["MARKET", "ENERGY", "NATIVE", "FALCON", "ORANGE", "RETELL"]
          },
          "rhymeagrams": {},
          "tumblepuns": {}
        }
        """.data(using: .utf8)!
        StubURLProtocol.handler = { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, payload)
        }

        let service = PuzzleContentService(session: stubSession(), cacheURL: cacheURL)
        await service.refresh()

        XCTAssertNotNil(service.manifest()?.diagone[remoteOnlyKey])
        XCTAssertNotNil(PuzzleContentService(cacheURL: cacheURL).manifest()?.diagone[remoteOnlyKey])
    }

    func testRejectedRemoteResponsesPreserveLastValidCache() async throws {
        enum Scenario: CaseIterable {
            case invalidMIME, invalidSchema, oversized, offline
        }

        for scenario in Scenario.allCases {
            let cacheURL = temporaryCacheURL()
            let cachedKey = "12/30/2026"
            try cachedManifest(diagoneKey: cachedKey).write(to: cacheURL, options: .atomic)

            StubURLProtocol.handler = { request in
                if scenario == .offline {
                    throw URLError(.notConnectedToInternet)
                }
                let contentType = scenario == .invalidMIME ? "text/plain" : "application/json"
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": contentType]
                ))
                switch scenario {
                case .invalidMIME:
                    return (response, Data("{}".utf8))
                case .invalidSchema:
                    return (response, Data("{\"schemaVersion\":2,\"diagone\":{},\"rhymeagrams\":{},\"tumblepuns\":{}}".utf8))
                case .oversized:
                    return (response, Data(repeating: 0x20, count: SecurityPolicy.maximumPuzzleManifestBytes + 1))
                case .offline:
                    throw URLError(.notConnectedToInternet)
                }
            }

            let service = PuzzleContentService(session: stubSession(), cacheURL: cacheURL)
            await service.refresh()

            XCTAssertNotNil(service.manifest()?.diagone[cachedKey], "Lost cache for \(scenario)")
            XCTAssertNotNil(PuzzleContentService(cacheURL: cacheURL).manifest()?.diagone[cachedKey], "Overwrote cache for \(scenario)")
            XCTAssertNotNil(service.lastValidationFailure(), "Did not record failure for \(scenario)")
        }
    }

    private func temporaryCacheURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    private func stubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func cachedManifest(diagoneKey: String) -> Data {
        Data("""
        {
          "schemaVersion": 1,
          "diagone": {
            "\(diagoneKey)": ["MARKET", "ENERGY", "NATIVE", "FALCON", "ORANGE", "RETELL"]
          },
          "rhymeagrams": {},
          "tumblepuns": {}
        }
        """.utf8)
    }

    private func validManifest() -> PuzzleContentManifest {
        PuzzleContentManifest(
            schemaVersion: 1,
            diagone: [
                "06/01/2026": ["PLANET", "GARDEN", "SILVER", "BRIDGE", "CANDLE", "POCKET"]
            ],
            rhymeagrams: [
                "06/01/2026": .init(
                    letters: ["G", "AFN", "SAAEE", "EEAMMMM"],
                    solutions: ["GAME", "FAME", "NAME", "SAME"]
                )
            ],
            tumblepuns: [
                "06/01/2026": .init(
                    words: [
                        .init(scrambled: "ONEST", solution: "STONE", shadedIndices: [2, 4]),
                        .init(scrambled: "NOMEL", solution: "LEMON", shadedIndices: [2]),
                        .init(scrambled: "HCNIP", solution: "PINCH", shadedIndices: [2]),
                        .init(scrambled: "LNIAS", solution: "SNAIL", shadedIndices: [1, 2])
                    ],
                    definition: "A match with love on the court",
                    answerPattern: "______",
                    answer: "TENNIS"
                )
            ]
        )
    }
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
