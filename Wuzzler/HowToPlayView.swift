import SwiftUI

struct HowToPlayView: View {
    @State private var selectedGame: GameType = .diagone

    var body: some View {
        VStack(spacing: 0) {
            Picker("Game", selection: $selectedGame) {
                ForEach(GameType.allCases) { game in
                    Text(game.displayName).tag(game)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(spacing: 24) {
                    ForEach(Array(tutorialSteps(for: selectedGame).enumerated()), id: \.offset) { _, step in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: step.icon)
                                .font(.title3)
                                .foregroundStyle(selectedGame.accentColor)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(selectedGame.accentColor.opacity(0.12))
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.headline)
                                Text(step.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("How to Play")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tutorialSteps(for game: GameType) -> [TutorialStep] {
        switch game {
        case .diagone:
            return [
                TutorialStep(icon: "square.grid.3x3", title: "Welcome to Diagone", description: "Place diagonal word chips onto a 6x6 board to spell six horizontal words."),
                TutorialStep(icon: "hand.draw", title: "Drag & Drop", description: "Drag chips from the tray onto the board. Each chip fills a diagonal of matching length."),
                TutorialStep(icon: "arrow.uturn.backward", title: "Rearrange Freely", description: "Drag a placed chip to a different diagonal, or drag it off the board to remove it."),
                TutorialStep(icon: "character.textbox", title: "Complete the Diagonal", description: "Once all chips are placed, type letters into the highlighted main diagonal to finish the puzzle."),
            ]
        case .rhymeAGrams:
            return [
                TutorialStep(icon: "triangle", title: "Welcome to RhymeAGrams", description: "Find four 4-letter rhyming words hidden in the pyramid of letters. All four words rhyme!"),
                TutorialStep(icon: "hand.tap", title: "Tap to Spell", description: "Tap letters in the pyramid or use the keyboard to spell each word. Every letter is used exactly once across all four words."),
                TutorialStep(icon: "arrow.right.arrow.left", title: "Navigate Words", description: "Tap any answer row to select it. Words auto-advance when filled. Backspace moves to the previous word if the current one is empty."),
            ]
        case .tumblePuns:
            return [
                TutorialStep(icon: "circle.grid.3x3", title: "Welcome to TumblePuns", description: "Unscramble four jumbled words, then use the highlighted letters to solve a punny clue."),
                TutorialStep(icon: "arrow.triangle.2.circlepath", title: "Unscramble Words", description: "Tap a word to select it, then type the correct spelling. Use the shuffle button to rearrange the scrambled letters for a fresh look."),
                TutorialStep(icon: "paintbrush.pointed", title: "Shaded Letters", description: "Each solved word reveals its shaded letters. These special letters combine to form the final answer."),
                TutorialStep(icon: "lightbulb", title: "Solve the Pun", description: "Read the definition clue, then unscramble the shaded letters to complete the punny final answer."),
            ]
        }
    }
}
