import SwiftUI

// MARK: - Confetti View

/// A single slow cascade of confetti that falls from top to bottom of the full screen.
/// Triggered once, it emits a wave of particles that drift down over ~4 seconds.
struct ConfettiView: View {
    let trigger: Int  // Increment to fire a new cascade
    let colors: [Color]

    @State private var particles: [ConfettiParticle] = []
    @State private var activeTrigger: Int = 0

    init(trigger: Int, colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]) {
        self.trigger = trigger
        self.colors = colors
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    for particle in particles {
                        let age = now - particle.startTime
                        guard age > 0, age < particle.lifetime else { continue }

                        // Steady downward fall with gentle sine-wave drift
                        let x = particle.startX + sin(age * particle.wobbleFreq) * particle.wobbleAmp
                        let y = -20 + particle.speed * age
                        let progress = age / particle.lifetime

                        // Fade out in the last 20%
                        let opacity = progress > 0.8 ? (1.0 - progress) / 0.2 : 1.0

                        guard y < height + 30 else { continue }

                        let rotation = Angle(degrees: particle.rotationSpeed * age)
                        let sz = particle.size

                        context.opacity = opacity
                        context.translateBy(x: x, y: y)
                        context.rotate(by: rotation)

                        if particle.isCircle {
                            let rect = CGRect(x: -sz/2, y: -sz/2, width: sz, height: sz)
                            context.fill(Circle().path(in: rect), with: .color(particle.color))
                        } else {
                            let rect = CGRect(x: -sz/2, y: -sz * 0.3, width: sz, height: sz * 0.6)
                            context.fill(RoundedRectangle(cornerRadius: 2).path(in: rect), with: .color(particle.color))
                        }

                        context.rotate(by: -rotation)
                        context.translateBy(x: -x, y: -y)
                        context.opacity = 1
                    }
                }
            }
            .onChange(of: trigger) { _, newValue in
                if newValue != activeTrigger {
                    activeTrigger = newValue
                    emitCascade(width: width, height: height)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func emitCascade(width: CGFloat, height: CGFloat) {
        let now = Date().timeIntervalSinceReferenceDate
        // Fall duration: time for a particle to traverse the full screen height
        let fallDuration: Double = 3.5

        var newParticles: [ConfettiParticle] = []
        let count = 80

        for _ in 0..<count {
            // Stagger start times over ~0.6s so it looks like a wave
            let delay = Double.random(in: 0...0.6)
            let speed = (height + 50) / fallDuration * Double.random(in: 0.7...1.3)

            newParticles.append(ConfettiParticle(
                startTime: now + delay,
                startX: CGFloat.random(in: 10...(width - 10)),
                speed: speed,
                wobbleAmp: CGFloat.random(in: 8...25),
                wobbleFreq: Double.random(in: 1.5...4.0),
                rotationSpeed: Double.random(in: -300...300),
                size: CGFloat.random(in: 6...12),
                color: colors.randomElement() ?? .blue,
                isCircle: Bool.random(),
                lifetime: fallDuration + delay + 0.5
            ))
        }

        particles = newParticles

        // Clean up after all particles are done
        let totalDuration = fallDuration + 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            particles.removeAll()
        }
    }
}

private struct ConfettiParticle {
    let startTime: TimeInterval
    let startX: CGFloat
    let speed: Double       // points per second downward
    let wobbleAmp: CGFloat  // horizontal sine amplitude
    let wobbleFreq: Double  // horizontal sine frequency
    let rotationSpeed: Double
    let size: CGFloat
    let color: Color
    let isCircle: Bool
    let lifetime: TimeInterval
}

// MARK: - Personal Best Toast

/// A transient toast that slides in from the top when the player achieves a personal best.
struct PersonalBestToast: View {
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            VStack {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Personal Best!")
                            .font(.subheadline.weight(.bold))
                        Text("Your fastest solve ever")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                )
                .transition(.move(edge: .top).combined(with: .opacity))

                Spacer()
            }
            .padding(.top, 60)
            .onAppear {
                Haptics.notify(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// MARK: - Milestone Toast

/// A transient toast celebrating streak milestones (7, 14, 30, 50, 100, etc.)
struct MilestoneToast: View {
    let streakCount: Int
    @Binding var isShowing: Bool

    private var milestoneMessage: String? {
        switch streakCount {
        case 7: return "One week streak!"
        case 14: return "Two week streak!"
        case 30: return "One month streak!"
        case 50: return "50 day streak!"
        case 100: return "100 day streak!"
        case 365: return "One year streak!"
        default:
            if streakCount > 0 && streakCount % 100 == 0 { return "\(streakCount) day streak!" }
            return nil
        }
    }

    var body: some View {
        if isShowing, let message = milestoneMessage {
            VStack {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    Text(message)
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                )
                .transition(.move(edge: .top).combined(with: .opacity))

                Spacer()
            }
            .padding(.top, 60)
            .onAppear {
                Haptics.impact(.medium)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}
