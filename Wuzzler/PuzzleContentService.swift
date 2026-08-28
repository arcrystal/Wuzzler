import Foundation
import OSLog

extension Notification.Name {
    static let puzzleContentDidRefresh = Notification.Name("PuzzleContentDidRefresh")
}

struct PuzzleContentManifest: Decodable {
    let schemaVersion: Int?
    let diagone: [String: [String]]
    let rhymeagrams: [String: RhymeAGramsPuzzleLibrary.PuzzleData]
    let tumblepuns: [String: TumblePunsPuzzleLibrary.PuzzleData]
}

final class PuzzleContentService {
    static let shared = PuzzleContentService()

    static let remoteURL = SecurityPolicy.remotePuzzleContentURL

    private let session: URLSession
    private let cacheFileURL: URL
    private let lock = NSLock()
    private var cachedManifest: PuzzleContentManifest?
    private var bundledManifest: PuzzleContentManifest?
    private var lastFailure: String?
    private let logger = Logger(subsystem: "CotterCrystal.Wuzzler", category: "PuzzleContent")

    private static var defaultCacheURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Wuzzler", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("puzzles-v1.json")
    }

    init(session: URLSession = SecurityPolicy.puzzleContentURLSession(), cacheURL: URL? = nil) {
        self.session = session
        self.cacheFileURL = cacheURL ?? Self.defaultCacheURL
        self.bundledManifest = Self.loadBundledManifest()

        guard let manifest = Self.loadManifest(from: cacheFileURL) else { return }
        let failures = Self.validationFailures(in: manifest)
        if failures.isEmpty {
            cachedManifest = manifest
        } else {
            lastFailure = "Cached puzzle content rejected: \(failures.joined(separator: " "))"
        }
    }

    func refresh() async {
        guard SecurityPolicy.isApprovedRemoteContentURL(Self.remoteURL) else {
            recordValidationFailure("Remote puzzle content URL is not approved.")
            return
        }
        var request = URLRequest(url: Self.remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 3)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard SecurityPolicy.isApprovedRemoteContentResponse(response) else {
                recordValidationFailure("Remote puzzle content response came from an unapproved URL.")
                return
            }
            guard let http = response as? HTTPURLResponse else {
                recordValidationFailure("Remote puzzle content returned a non-HTTP response.")
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                recordValidationFailure("Remote puzzle content returned HTTP \(http.statusCode).")
                return
            }
            guard SecurityPolicy.isApprovedJSONMimeType(http.mimeType) else {
                recordValidationFailure("Remote puzzle content returned an unexpected content type.")
                return
            }
            guard SecurityPolicy.isResponseSizeAllowed(data.count) else {
                recordValidationFailure("Remote puzzle content exceeded the maximum allowed size.")
                return
            }
            let manifest = try JSONDecoder().decode(PuzzleContentManifest.self, from: data)
            try validate(manifest)
            try SecurityPolicy.writeProtectedCacheData(data, to: cacheFileURL)

            updateCachedManifest(manifest)

            await MainActor.run {
                NotificationCenter.default.post(name: .puzzleContentDidRefresh, object: nil)
            }
        } catch {
            recordValidationFailure("Remote puzzle content unavailable: \(error.localizedDescription)")
        }
    }

    func manifest() -> PuzzleContentManifest? {
        lock.lock()
        let manifest = Self.mergedManifest(bundled: bundledManifest, cached: cachedManifest)
        lock.unlock()
        return manifest
    }

    func diagoneMap() -> [String: [String]]? {
        manifest()?.diagone
    }

    func rhymeAGramsMap() -> [String: RhymeAGramsPuzzleLibrary.PuzzleData]? {
        manifest()?.rhymeagrams
    }

    func tumblePunsMap() -> [String: TumblePunsPuzzleLibrary.PuzzleData]? {
        manifest()?.tumblepuns
    }

    func hasPuzzle(for game: GameType, on date: Date) -> Bool {
        let key = PuzzleDay.puzzleKey(for: date)
        guard let manifest = manifest() else { return false }
        switch game {
        case .diagone:
            return manifest.diagone[key] != nil
        case .rhymeAGrams:
            return manifest.rhymeagrams[key] != nil
        case .tumblePuns:
            return manifest.tumblepuns[key] != nil
        }
    }

    func logMissingTodayPuzzles() {
        let missing = GameType.allCases.filter { !hasPuzzle(for: $0, on: PuzzleDay.today) }
        guard !missing.isEmpty else { return }
        let names = missing.map(\.displayName).joined(separator: ", ")
        recordValidationFailure("Missing UTC puzzle content for \(PuzzleDay.storageKey(for: PuzzleDay.today)): \(names).")
    }

    func lastValidationFailure() -> String? {
        lock.lock()
        let failure = lastFailure
        lock.unlock()
        return failure
    }

    func validationFailures(for manifest: PuzzleContentManifest) -> [String] {
        Self.validationFailures(in: manifest)
    }

    private static func validationFailures(in manifest: PuzzleContentManifest) -> [String] {
        var failures: [String] = []
        if manifest.schemaVersion != 1 {
            failures.append("Puzzle manifest schemaVersion must be 1.")
        }
        for (date, words) in manifest.diagone {
            if PuzzleDay.date(fromPuzzleKey: date) == nil {
                failures.append("Diagone has invalid date key \(date).")
            }
            if words.count != 6 {
                failures.append("Diagone \(date) must contain six row words.")
            }
            for (index, word) in words.enumerated() {
                if word.count != 6 || !Self.isLettersOnly(word) {
                    failures.append("Diagone \(date) row \(index + 1) must be a six-letter A-Z word.")
                }
            }
        }
        for (date, puzzle) in manifest.rhymeagrams {
            if PuzzleDay.date(fromPuzzleKey: date) == nil {
                failures.append("RhymeAGram has invalid date key \(date).")
            }
            if puzzle.letters.map(\.count) != [1, 3, 5, 7] || puzzle.solutions.count != 4 {
                failures.append("RhymeAGram \(date) has invalid letters or solutions.")
            }
            if puzzle.letters.contains(where: { !Self.isLettersOnly($0) }) {
                failures.append("RhymeAGram \(date) letter rows must contain only A-Z.")
            }
            if puzzle.solutions.contains(where: { $0.count != 4 || !Self.isLettersOnly($0) }) {
                failures.append("RhymeAGram \(date) solutions must be four-letter A-Z words.")
            }
            if Self.letterCounts(puzzle.letters.joined()) != Self.letterCounts(puzzle.solutions.joined()) {
                failures.append("RhymeAGram \(date) displayed letters do not match solution letters exactly.")
            }
        }
        for (date, puzzle) in manifest.tumblepuns {
            if PuzzleDay.date(fromPuzzleKey: date) == nil {
                failures.append("TumblePun has invalid date key \(date).")
            }
            if puzzle.words.count != 4 || !Self.isAnswerText(puzzle.answer) || !Self.isDisplayText(puzzle.definition, maxLength: 180) {
                failures.append("TumblePun \(date) has invalid words, answer, or clue.")
            }
            var shadedLetters = ""
            for (index, word) in puzzle.words.enumerated() {
                if !(2...16).contains(word.solution.count) || !Self.isLettersOnly(word.solution) {
                    failures.append("TumblePun \(date) word \(index + 1) needs an A-Z solution.")
                    continue
                }
                if let scrambled = word.scrambled {
                    if scrambled.count != word.solution.count || !Self.isLettersOnly(scrambled) {
                        failures.append("TumblePun \(date) word \(index + 1) scrambled letters must contain only A-Z.")
                    }
                    if Self.letterCounts(scrambled) != Self.letterCounts(word.solution) {
                        failures.append("TumblePun \(date) word \(index + 1) scrambled letters do not match the solution.")
                    }
                }
                if word.shadedIndices.isEmpty {
                    failures.append("TumblePun \(date) word \(index + 1) needs shaded indices.")
                    continue
                }
                for shadedIndex in word.shadedIndices {
                    if shadedIndex < 1 || shadedIndex > word.solution.count {
                        failures.append("TumblePun \(date) word \(index + 1) has invalid shaded index \(shadedIndex).")
                    } else {
                        let stringIndex = word.solution.index(word.solution.startIndex, offsetBy: shadedIndex - 1)
                        shadedLetters.append(word.solution[stringIndex])
                    }
                }
            }
            let answerLetters = puzzle.answer.filter(\.isLetter)
            if answerLetters.isEmpty {
                failures.append("TumblePun \(date) answer must contain letters.")
            }
            if Self.letterCounts(shadedLetters) != Self.letterCounts(String(answerLetters)) {
                failures.append("TumblePun \(date) shaded letters do not match answer letters exactly.")
            }
            if let pattern = puzzle.answerPattern {
                if pattern.count > 40 || !Self.hasNoControlCharacters(pattern) {
                    failures.append("TumblePun \(date) answer pattern is too long or contains control characters.")
                }
                let expected = puzzle.answer.map { $0.isLetter ? "_" : String($0) }.joined()
                if pattern != expected {
                    failures.append("TumblePun \(date) answer pattern should be \(expected).")
                }
            }
        }
        return failures
    }

    private func validate(_ manifest: PuzzleContentManifest) throws {
        let failures = validationFailures(for: manifest)
        if !failures.isEmpty {
            throw ValidationError(failures.joined(separator: " "))
        }
    }

    private func recordValidationFailure(_ message: String) {
        lock.lock()
        lastFailure = message
        lock.unlock()
        UserDefaults.standard.set(message, forKey: "puzzle_content_last_validation_failure")
        logger.error("Puzzle content update rejected: \(message, privacy: .public)")
    }

    private func updateCachedManifest(_ manifest: PuzzleContentManifest) {
        lock.lock()
        cachedManifest = manifest
        lastFailure = nil
        lock.unlock()
    }

    private static func loadManifest(from url: URL) -> PuzzleContentManifest? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard SecurityPolicy.isResponseSizeAllowed(data.count) else { return nil }
        return try? JSONDecoder().decode(PuzzleContentManifest.self, from: data)
    }

    private static func loadBundledManifest() -> PuzzleContentManifest? {
        if let manifest = loadCombinedBundledManifest() {
            return manifest
        }
        guard let diagone = loadBundledDiagoneMap(),
              let rhymeagrams = loadBundledRhymeAGramsMap(),
              let tumblepuns = loadBundledTumblePunsMap() else {
            return nil
        }
        let manifest = PuzzleContentManifest(
            schemaVersion: 1,
            diagone: diagone,
            rhymeagrams: rhymeagrams,
            tumblepuns: tumblepuns
        )
        return validationFailures(in: manifest).isEmpty ? manifest : nil
    }

    private static func loadCombinedBundledManifest() -> PuzzleContentManifest? {
        loadBundledJSON(resource: "puzzles", subdirectory: "Content")
            .flatMap { try? JSONDecoder().decode(PuzzleContentManifest.self, from: $0) }
    }

    private static func loadBundledDiagoneMap() -> [String: [String]]? {
        guard let data = loadBundledJSON(resource: "puzzles", subdirectory: "Puzzles") else { return nil }
        if let map = try? JSONDecoder().decode([String: [String]].self, from: data) { return map }
        if let wrapped = try? JSONDecoder().decode(DiagoneStore.self, from: data) { return wrapped.map }
        return nil
    }

    private static func loadBundledRhymeAGramsMap() -> [String: RhymeAGramsPuzzleLibrary.PuzzleData]? {
        guard let data = loadBundledJSON(resource: "rhymeagrams_puzzles") else { return nil }
        return try? JSONDecoder().decode([String: RhymeAGramsPuzzleLibrary.PuzzleData].self, from: data)
    }

    private static func loadBundledTumblePunsMap() -> [String: TumblePunsPuzzleLibrary.PuzzleData]? {
        guard let data = loadBundledJSON(resource: "tumblepuns_puzzles") else { return nil }
        return try? JSONDecoder().decode([String: TumblePunsPuzzleLibrary.PuzzleData].self, from: data)
    }

    private static func loadBundledJSON(resource: String, subdirectory: String? = nil) -> Data? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: resource, withExtension: "json", subdirectory: subdirectory),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = bundle.url(forResource: resource, withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }

    private static func mergedManifest(bundled: PuzzleContentManifest?, cached: PuzzleContentManifest?) -> PuzzleContentManifest? {
        switch (bundled, cached) {
        case let (bundled?, cached?):
            return PuzzleContentManifest(
                schemaVersion: 1,
                diagone: bundled.diagone.merging(cached.diagone) { _, cached in cached },
                rhymeagrams: bundled.rhymeagrams.merging(cached.rhymeagrams) { _, cached in cached },
                tumblepuns: bundled.tumblepuns.merging(cached.tumblepuns) { _, cached in cached }
            )
        case let (bundled?, nil):
            return bundled
        case let (nil, cached?):
            return cached
        case (nil, nil):
            return nil
        }
    }

    private struct DiagoneStore: Decodable {
        let map: [String: [String]]
    }

    private static func isLettersOnly(_ value: String) -> Bool {
        !value.isEmpty && value.range(of: "^[A-Za-z]+$", options: .regularExpression) != nil
    }

    private static func letterCounts(_ value: String) -> [Character: Int] {
        value.uppercased().filter(\.isLetter).reduce(into: [:]) { counts, character in
            counts[character, default: 0] += 1
        }
    }

    private static func isDisplayText(_ value: String, maxLength: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            value.count <= maxLength &&
            hasNoControlCharacters(value)
    }

    private static func isAnswerText(_ value: String) -> Bool {
        let pattern = "^[A-Za-z][A-Za-z -]{0,38}[A-Za-z]$|^[A-Za-z]$"
        return value.count <= 40 &&
            hasNoControlCharacters(value) &&
            value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func hasNoControlCharacters(_ value: String) -> Bool {
        !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    private struct ValidationError: LocalizedError {
        let message: String

        init(_ message: String) {
            self.message = message
        }

        var errorDescription: String? { message }
    }
}
