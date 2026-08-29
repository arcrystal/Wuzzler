import SwiftUI

/// Shared Play-to-game transition. It renders a determinate loading state before
/// doing cold haptic setup, then refreshes the prepared state immediately before
/// handing control to the interactive puzzle.
struct PuzzlePreparationControl: View {
    let gameName: String
    let accessibilityPrefix: String
    let onStart: () -> Void

    @Environment(\.gameAccent) private var gameAccent
    @State private var isLoading = false
    @State private var progress = 0.0
    @State private var loadingTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 10) {
                    Text("Loading puzzle...")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ProgressView(value: progress, total: 1)
                        .tint(gameAccent)
                        .accessibilityLabel("Loading \(gameName)")
                        .accessibilityValue("\(Int(progress * 100)) percent")
                        .accessibilityIdentifier("\(accessibilityPrefix)-start-progress")
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, minHeight: 58)
                .transition(.opacity)
            } else {
                Button(action: beginLoading) {
                    Text("Play")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(gameAccent))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                }
                .accessibilityIdentifier("\(accessibilityPrefix)-start-button")
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isLoading)
        .onDisappear {
            loadingTask?.cancel()
            loadingTask = nil
        }
    }

    private func beginLoading() {
        guard !isLoading else { return }
        isLoading = true
        progress = 0

        loadingTask = Task { @MainActor in
            let clock = ContinuousClock()
            let loadingStartedAt = clock.now

            // Let the empty bar render before any potentially cold setup begins.
            do {
                try await Task.sleep(for: .milliseconds(30))
            } catch {
                return
            }

            Haptics.prepare()

            withAnimation(.linear(duration: 0.65)) {
                progress = 1
            }

            do {
                try await Task.sleep(for: .milliseconds(680))
            } catch {
                return
            }

            Haptics.prepare()

            if let minimumDuration = SecurityPolicy.uiTestPuzzleLoadingMinimumDuration {
                let minimum = Duration.milliseconds(Int64((minimumDuration * 1_000).rounded()))
                let elapsed = loadingStartedAt.duration(to: clock.now)
                if elapsed < minimum {
                    do {
                        try await Task.sleep(for: minimum - elapsed)
                    } catch {
                        return
                    }
                }
            }

            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }

            onStart()
        }
    }
}
