import SwiftUI

/// A single step in a game tutorial sequence.
struct TutorialStep {
    let icon: String
    let title: String
    let description: String
}

/// A reusable multi-step tutorial overlay shown the first time a user plays a game.
/// Presents paginated cards with SF Symbol icons, titles, descriptions, page dots,
/// and Skip / Next navigation.
struct TutorialOverlay: View {
    let steps: [TutorialStep]
    let accentColor: Color
    let onDismiss: () -> Void

    @State private var currentStep: Int = 0
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps */ }

            // Card
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Step content with animated transitions
                    stepContent
                        .id(currentStep)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                    // Page dots
                    if steps.count > 1 {
                        pageDots
                    }

                    // Navigation buttons
                    navigationButtons
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 24)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
                )
                .padding(.horizontal, 24)

                Spacer()
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.92)
        }
        .animation(.easeOut(duration: 0.3), value: appeared)
        .onAppear {
            appeared = true
        }
    }

    // MARK: - Step Content

    private var stepContent: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: steps[currentStep].icon)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 72, height: 72)
                .background(
                    Circle()
                        .fill(accentColor.opacity(0.12))
                )

            // Title
            Text(steps[currentStep].title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)

            // Description
            Text(steps[currentStep].description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == currentStep ? 8 : 6,
                           height: index == currentStep ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            // Skip button
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    appeared = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onDismiss()
                }
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            Spacer()

            // Next / Get Started button
            Button {
                if currentStep < steps.count - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep += 1
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        appeared = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onDismiss()
                    }
                }
            } label: {
                Text(currentStep < steps.count - 1 ? "Next" : "Get Started")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(accentColor)
                    )
            }
        }
    }
}
