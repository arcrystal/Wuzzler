import Foundation

/// Represents a single word scramble in TumblePuns
public struct TumbleWord: Codable {
    public let scrambled: String  // The scrambled letters
    public let solution: String   // The unscrambled word
    public let shadedIndices: [Int]  // Which letter positions are shaded (1-indexed)

    public init(scrambled: String, solution: String, shadedIndices: [Int]) {
        self.scrambled = scrambled.uppercased()
        self.solution = solution.uppercased()
        self.shadedIndices = shadedIndices
    }
}

/// Represents a TumblePuns puzzle
public struct TumblePunsPuzzle: Codable {
    public let words: [TumbleWord]  // The four scrambled words
    public let definition: String   // The clue text
    public let answerPattern: String  // Pattern like "___-_____" showing word breaks
    public let answer: String  // The final answer (unscrambled shaded letters)

    public init(words: [TumbleWord], definition: String, answerPattern: String, answer: String) {
        precondition(words.count == 4, "Must have 4 words")
        self.words = words
        self.definition = definition
        self.answerPattern = answerPattern
        self.answer = answer.uppercased()
    }
}

/// Game state for TumblePuns
struct TumblePunsState: Codable {
    var wordAnswers: [String]  // User's answers for the 4 words
    var finalAnswer: String    // User's answer for the final unscramble
    var selectedWordIndex: Int?  // Which word is currently selected (0-3)
    var isFinalAnswerSelected: Bool  // Whether the final answer input is selected

    init() {
        self.wordAnswers = ["", "", "", ""]
        self.finalAnswer = ""
        self.selectedWordIndex = nil
        self.isFinalAnswerSelected = false
    }

    mutating func setWordAnswer(at index: Int, to value: String) {
        guard index >= 0 && index < 4 else { return }
        wordAnswers[index] = value.uppercased()
    }

    mutating func appendLetter(_ letter: String, to index: Int) {
        guard index >= 0 && index < 4 else { return }
        let maxLength = wordAnswers[index].count < 20 ? 20 : wordAnswers[index].count
        if wordAnswers[index].count < maxLength {
            wordAnswers[index] += letter.uppercased()
        }
    }

    mutating func appendLetterToFinal(_ letter: String) {
        if finalAnswer.count < 30 {
            finalAnswer += letter.uppercased()
        }
    }

    mutating func deleteLetter(from index: Int) {
        guard index >= 0 && index < 4 else { return }
        if !wordAnswers[index].isEmpty {
            wordAnswers[index] = String(wordAnswers[index].dropLast())
        }
    }

    mutating func deleteLetterFromFinal() {
        if !finalAnswer.isEmpty {
            finalAnswer = String(finalAnswer.dropLast())
        }
    }
}

/// TumblePuns game engine
class TumblePunsEngine {
    let puzzle: TumblePunsPuzzle
    private(set) var state: TumblePunsState

    init(puzzle: TumblePunsPuzzle) {
        self.puzzle = puzzle
        self.state = TumblePunsState()
    }

    init(puzzle: TumblePunsPuzzle, state: TumblePunsState) {
        self.puzzle = puzzle
        self.state = state
    }

    func selectWord(_ index: Int?) {
        state.selectedWordIndex = index
        state.isFinalAnswerSelected = false
    }

    func selectFinalAnswer() {
        state.selectedWordIndex = nil
        state.isFinalAnswerSelected = true
    }

    func appendLetter(_ letter: String) {
        if state.isFinalAnswerSelected {
            let maxLength = puzzle.answerPattern.filter({ $0 == "_" }).count
            guard state.finalAnswer.count < maxLength else { return }
            state.appendLetterToFinal(letter)
        } else if let index = state.selectedWordIndex {
            let maxLength = puzzle.words[index].solution.count
            guard state.wordAnswers[index].count < maxLength else { return }
            state.appendLetter(letter, to: index)
        }
    }

    func deleteLetter() {
        if state.isFinalAnswerSelected {
            state.deleteLetterFromFinal()
        } else if let index = state.selectedWordIndex {
            state.deleteLetter(from: index)
        }
    }

    func clearWord(at index: Int) {
        guard index >= 0 && index < 4 else { return }
        state.wordAnswers[index] = ""
    }

    func clearFinalAnswer() {
        state.finalAnswer = ""
    }

    /// Check if all four words are correctly solved
    var areWordsSolved: Bool {
        for (index, word) in puzzle.words.enumerated() {
            if state.wordAnswers[index] != word.solution {
                return false
            }
        }
        return true
    }

    /// Check if the puzzle is completely solved (words + final answer)
    var isSolved: Bool {
        guard areWordsSolved else { return false }
        // Remove spaces and dashes from both answers for comparison
        let cleanFinalAnswer = state.finalAnswer.filter { $0.isLetter }
        let cleanSolution = puzzle.answer.filter { $0.isLetter }
        return cleanFinalAnswer == cleanSolution
    }

    /// Get indices of correctly solved words
    var correctWordIndices: Set<Int> {
        var correct = Set<Int>()
        for (index, word) in puzzle.words.enumerated() {
            if state.wordAnswers[index] == word.solution {
                correct.insert(index)
            }
        }
        return correct
    }

    /// Get the shaded letters from all correctly solved words
    var shadedLetters: String {
        var letters = ""
        for (index, word) in puzzle.words.enumerated() {
            if state.wordAnswers[index] == word.solution {
                for shadedIndex in word.shadedIndices {
                    if shadedIndex > 0 && shadedIndex <= word.solution.count {
                        let idx = word.solution.index(word.solution.startIndex, offsetBy: shadedIndex - 1)
                        letters.append(word.solution[idx])
                    }
                }
            }
        }
        return letters
    }
}

/// Puzzle library for TumblePuns
enum TumblePunsPuzzleLibrary {
    struct PuzzleData: Decodable {
        struct WordData: Decodable {
            let scrambled: String?
            let solution: String
            let shadedIndices: [Int]
        }

        let words: [WordData]
        let definition: String
        let answerPattern: String?
        let answer: String
    }

    private static var cache: [String: PuzzleData]?
    private static var cacheLoaded = false

    static func loadPuzzleMap(resource: String = "tumblepuns_puzzles", subdirectory: String? = nil) -> [String: PuzzleData]? {
        if cacheLoaded { return cache }
        let bundle = Bundle.main

        if let url = bundle.url(forResource: resource, withExtension: "json", subdirectory: subdirectory),
           let data = try? Data(contentsOf: url),
           let map = try? JSONDecoder().decode([String: PuzzleData].self, from: data) {
            cache = map; cacheLoaded = true
            return map
        }

        if let url = bundle.url(forResource: resource, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let map = try? JSONDecoder().decode([String: PuzzleData].self, from: data) {
            cache = map; cacheLoaded = true
            return map
        }

        cacheLoaded = true
        return nil
    }

    /// Returns all date keys (MM/dd/yyyy format) that have puzzles available.
    static func availableDateKeys() -> Set<String> {
        guard let map = loadPuzzleMap() else { return [] }
        return Set(map.keys)
    }

    static func loadPuzzle(for date: Date) -> TumblePunsPuzzle {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateKey = formatter.string(from: date)

        if let puzzleMap = loadPuzzleMap(),
           let puzzleData = puzzleMap[dateKey] {
            let words = puzzleData.words.map { word in
                let scrambled = word.scrambled ?? Self.scramble(word.solution, seed: dateKey)
                return TumbleWord(scrambled: scrambled, solution: word.solution, shadedIndices: word.shadedIndices)
            }
            let answerPattern = puzzleData.answerPattern ?? Self.derivePattern(from: puzzleData.answer)
            return TumblePunsPuzzle(
                words: words,
                definition: puzzleData.definition,
                answerPattern: answerPattern,
                answer: puzzleData.answer
            )
        }

        // Fallback to default puzzle
        let words = [
            TumbleWord(scrambled: "DYTIZ", solution: "DITZY", shadedIndices: [2]),
            TumbleWord(scrambled: "DWONWI", solution: "WINDOW", shadedIndices: [4, 5]),
            TumbleWord(scrambled: "XEPPELR", solution: "PERPLEX", shadedIndices: [2, 5]),
            TumbleWord(scrambled: "AJIMYTOR", solution: "MAJORITY", shadedIndices: [1, 5, 7])
        ]
        return TumblePunsPuzzle(
            words: words,
            definition: "A sundial",
            answerPattern: "___-_____",
            answer: "OLD-TIMER"
        )
    }

    /// Derive an answer pattern from the answer string (e.g. "OLD-TIMER" → "___-_____")
    private static func derivePattern(from answer: String) -> String {
        String(answer.map { $0.isLetter ? Character("_") : $0 })
    }

    /// Deterministically scramble a word using a seed string so the same date always
    /// produces the same scramble, but the letters are shuffled.
    private static func scramble(_ word: String, seed: String) -> String {
        var chars = Array(word.uppercased())
        // Use a simple seeded shuffle based on the word + date
        var h = seed.hashValue &+ word.hashValue
        for i in stride(from: chars.count - 1, through: 1, by: -1) {
            h = h &* 6364136223846793005 &+ 1442695040888963407
            let j = abs(h) % (i + 1)
            chars.swapAt(i, j)
        }
        // If the scramble happens to match the original, swap first two
        let result = String(chars)
        if result == word.uppercased() && chars.count >= 2 {
            chars.swapAt(0, 1)
            return String(chars)
        }
        return result
    }
}
