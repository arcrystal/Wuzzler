import SwiftUI

struct TumblePunsLoadingView: View {
    let date: Date
    let onStart: () -> Void
    let onBack: () -> Void

    @Environment(\.gameAccent) private var gameAccent
    @AppStorage("tutorial_seen_tumblepuns") private var tutorialSeen = false
    @State private var showTutorial = false

    private var tutorialSteps: [TutorialStep] {
        [
            TutorialStep(
                icon: "circle.grid.3x3",
                title: "Welcome to TumblePun",
                description: "Unscramble four jumbled words, then use the highlighted letters to solve a punny clue."
            ),
            TutorialStep(
                icon: "arrow.triangle.2.circlepath",
                title: "Unscramble Words",
                description: "Tap a word to select it, then type the correct spelling. Use the shuffle button to rearrange the scrambled letters for a fresh look."
            ),
            TutorialStep(
                icon: "paintbrush.pointed",
                title: "Shaded Letters",
                description: "Each solved word reveals its shaded letters. These special letters combine to form the final answer."
            ),
            TutorialStep(
                icon: "lightbulb",
                title: "Solve the Pun",
                description: "Complete all four words to reveal the clue, then unscramble the shaded letters to find the punny final answer."
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.backward")
                        .font(.headline)
                        .padding()
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 80)

            TumblePunsIconView(size: 80)

            VStack(spacing: 12) {
                Text(formattedDate)
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .multilineTextAlignment(.center)

                Button(action: { showTutorial = true }) {
                    Label("How to Play", systemImage: "questionmark.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(gameAccent)
                }
            }

            PuzzlePreparationControl(
                gameName: "TumblePun",
                accessibilityPrefix: "tumblepuns",
                onStart: onStart
            )

            Spacer()

            VStack(spacing: 4) {
                Text(numberString).font(.subheadline).foregroundStyle(.secondary)
                Text("Edited by the Wuzzler team").font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showTutorial {
                TutorialOverlay(
                    steps: tutorialSteps,
                    accentColor: gameAccent,
                    onDismiss: {
                        tutorialSeen = true
                        showTutorial = false
                    }
                )
            }
        }
        .onAppear {
            if !tutorialSeen {
                showTutorial = true
            }
        }
    }

    private var formattedDate: String {
        PuzzleDay.displayDate(date, style: .long)
    }

    private var numberString: String {
        "No. \(PuzzleDay.puzzleNumber(for: date).dropFirst())"
    }
}
