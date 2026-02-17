import SwiftUI

struct RhymeAGramsLoadingView: View {
    let date: Date
    let onStart: () -> Void
    let onBack: () -> Void

    @Environment(\.gameAccent) private var gameAccent
    @AppStorage("tutorial_seen_rhymeagrams") private var tutorialSeen = false
    @State private var showTutorial = false

    private var tutorialSteps: [TutorialStep] {
        [
            TutorialStep(
                icon: "triangle",
                title: "Welcome to RhymeAGrams",
                description: "Find four 4-letter rhyming words hidden in the pyramid of letters. All four words rhyme!"
            ),
            TutorialStep(
                icon: "hand.tap",
                title: "Tap to Spell",
                description: "Tap letters in the pyramid or use the keyboard to spell each word. Every letter is used exactly once across all four words."
            ),
            TutorialStep(
                icon: "arrow.right.arrow.left",
                title: "Navigate Words",
                description: "Tap any answer row to select it. Words auto-advance when filled. Backspace moves to the previous word if the current one is empty."
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

            RhymeAGramsIconView(size: 80)

            VStack(spacing: 6) {
                Text(formattedDate)
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .multilineTextAlignment(.center)

                Text("Find four 4-letter rhyming words from a pyramid of letters")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }

            Button {
                onStart()
            } label: {
                Text("Play")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(gameAccent))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 4) {
                Text(numberString).font(.subheadline).foregroundStyle(.secondary)
                Text("Edited by Diagone Team").font(.subheadline).foregroundStyle(.secondary)
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
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none
        return df.string(from: date)
    }

    private var numberString: String {
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
        let seed = Int(df.string(from: date)) ?? 0
        return "No. \(seed % 5000)"
    }
}

fileprivate struct PyramidIcon: View {
    @Environment(\.gameAccent) private var gameAccent
    let size: CGFloat

    var body: some View {
        ZStack {
            // Triangle background
            Triangle()
                .fill(gameAccent.opacity(0.2))
                .frame(width: size, height: size * 0.866)  // Equilateral triangle ratio

            // Letter rows to suggest the game
            VStack(spacing: size * 0.08) {
                Text("A")
                    .font(.system(size: size * 0.15, weight: .semibold, design: .rounded))
                Text("BCD")
                    .font(.system(size: size * 0.12, weight: .semibold, design: .rounded))
                    .tracking(size * 0.06)
                Text("EFGHI")
                    .font(.system(size: size * 0.10, weight: .semibold, design: .rounded))
                    .tracking(size * 0.04)
                Text("JKLMNOP")
                    .font(.system(size: size * 0.08, weight: .semibold, design: .rounded))
                    .tracking(size * 0.03)
            }
            .foregroundColor(.primary)
            .offset(y: size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

fileprivate struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
