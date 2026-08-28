import SwiftUI

struct DiagoneLoadingView: View {
    let date: Date
    let onStart: () -> Void
    let onBack: () -> Void

    @Environment(\.gameAccent) private var gameAccent
    @AppStorage("tutorial_seen_diagone") private var tutorialSeen = false
    @State private var showTutorial = false

    private var tutorialSteps: [TutorialStep] {
        [
            TutorialStep(
                icon: "square.grid.3x3",
                title: "Welcome to Diagone",
                description: "Place diagonal word chips onto a 6×6 board to spell six horizontal words."
            ),
            TutorialStep(
                icon: "hand.draw",
                title: "Drag & Drop",
                description: "Drag chips from the tray onto the board. Each chip fills a diagonal of matching length."
            ),
            TutorialStep(
                icon: "arrow.uturn.backward",
                title: "Rearrange Freely",
                description: "Drag a placed chip to a different diagonal, or drag it off the board to remove it."
            ),
            TutorialStep(
                icon: "character.textbox",
                title: "Complete the Diagonal",
                description: "Once all chips are placed, type letters into the highlighted main diagonal to finish the puzzle."
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
            DiagoneIconView(size: 80)

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
                gameName: "Diagone",
                accessibilityPrefix: "diagone",
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
