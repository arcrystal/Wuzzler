import Foundation

/// Builds rich Wordle-style emoji share cards for each game.
enum ShareCardBuilder {

    // MARK: - Diagone

    /// Generates a visual 6x6 grid share card.
    /// Main diagonal cells are highlighted with a blue square, others are white.
    static func diagoneCard(time: TimeInterval, streakCount: Int) -> String {
        let timeStr = formatTime(time)
        var lines: [String] = []
        lines.append("Wuzzler \u{2014} Diagone")
        lines.append("\u{23F1}\u{FE0F} \(timeStr)")
        lines.append("")

        // 6x6 grid: main diagonal (where row == col) in blue, rest in white
        for row in 0..<6 {
            var rowStr = ""
            for col in 0..<6 {
                if row == col {
                    rowStr += "\u{1F7E6}" // blue square
                } else {
                    rowStr += "\u{2B1C}" // white square
                }
            }
            lines.append(rowStr)
        }

        lines.append("")
        if streakCount > 0 {
            lines.append("\u{1F525} \(streakCount) day streak")
        }
        lines.append("wuzzler.app")
        return lines.joined(separator: "\n")
    }

    // MARK: - RhymeAGrams

    /// Generates a pyramid-shaped share card with green squares for correct letters.
    static func rhymeAGramsCard(time: TimeInterval, streakCount: Int) -> String {
        let timeStr = formatTime(time)
        var lines: [String] = []
        lines.append("Wuzzler \u{2014} RhymeAGrams")
        lines.append("\u{23F1}\u{FE0F} \(timeStr)")
        lines.append("")

        // Pyramid: rows of 1, 3, 5, 7 (representing the letter pyramid)
        let rowCounts = [1, 3, 5, 7]
        let maxWidth = 7
        for count in rowCounts {
            let padding = String(repeating: "  ", count: (maxWidth - count) / 2)
            let squares = String(repeating: "\u{1F7E9}", count: count) // green squares
            lines.append(padding + squares)
        }

        lines.append("")
        // 4 words represented as 4-letter rows
        for _ in 0..<4 {
            lines.append("\u{1F7E9}\u{1F7E9}\u{1F7E9}\u{1F7E9}")
        }

        lines.append("")
        if streakCount > 0 {
            lines.append("\u{1F525} \(streakCount) day streak")
        }
        lines.append("wuzzler.app")
        return lines.joined(separator: "\n")
    }

    // MARK: - TumblePuns

    /// Generates a share card with word boxes and shaded-letter highlights.
    static func tumblePunsCard(
        wordLengths: [Int],
        shadedIndices: [[Int]],
        answerPattern: String,
        time: TimeInterval,
        streakCount: Int
    ) -> String {
        let timeStr = formatTime(time)
        var lines: [String] = []
        lines.append("Wuzzler \u{2014} TumblePuns")
        lines.append("\u{23F1}\u{FE0F} \(timeStr)")
        lines.append("")

        // Show each word as a mix of white and orange/red squares (shaded positions)
        for i in 0..<min(wordLengths.count, 4) {
            let length = wordLengths[i]
            let shaded = Set(shadedIndices[i])
            var rowStr = ""
            for pos in 1...length {
                if shaded.contains(pos) {
                    rowStr += "\u{1F7E7}" // orange for shaded letters
                } else {
                    rowStr += "\u{2B1C}" // white for regular
                }
            }
            lines.append(rowStr)
        }

        lines.append("")
        // Final answer pattern
        var answerRow = ""
        for ch in answerPattern {
            if ch == "_" {
                answerRow += "\u{1F7E7}" // orange
            } else {
                answerRow += String(ch)
            }
        }
        lines.append(answerRow)

        lines.append("")
        if streakCount > 0 {
            lines.append("\u{1F525} \(streakCount) day streak")
        }
        lines.append("wuzzler.app")
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
