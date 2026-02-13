import SwiftUI

struct HomeView: View {
    let onGameSelected: (GameType) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Wuzzler")
                    .font(.largeTitle.weight(.bold))
                    .padding(.top, 40)

                ForEach(GameType.allCases) { game in
                    GameCard(gameType: game, onTap: {
                        onGameSelected(game)
                    })
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(Color(UIColor.systemGray6))
    }
}

fileprivate struct GameCard: View {
    let gameType: GameType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                GameIconView(gameType: gameType)
                    .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 4) {
                    Text(gameType.displayName)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)

                    Text(gameType.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
            )
            .shadow(radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Game Icons
fileprivate struct GameIconView: View {
    let gameType: GameType

    var body: some View {
        switch gameType {
        case .diagone:
            DiagoneIconView(size: 54)
        case .rhymeAGrams:
            RhymeAGramsIconView(size: 54)
        case .tumblePuns:
            TumblePunsIconView(size: 54)
        }
    }
}

// Diagone: square with diagonal line
struct DiagoneIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .stroke(Color.mainDiagonal, lineWidth: 2.5)
            Path { path in
                path.move(to: CGPoint(x: size * 0.18, y: size * 0.18))
                path.addLine(to: CGPoint(x: size * 0.82, y: size * 0.82))
            }
            .stroke(Color.mainDiagonal, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

// RhymeAGrams: four stacked bars (1, 3, 5, 7)
struct RhymeAGramsIconView: View {
    let size: CGFloat

    var body: some View {
        let barHeight = size * 0.14
        let spacing = size * 0.06
        let lineWidth = size * 0.04
        let cornerRadius = barHeight * 0.3
        let widths: [CGFloat] = [1, 3, 5, 7].map { CGFloat($0) / 7.0 * size * 0.85 }
        VStack(spacing: spacing) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, w in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.mainDiagonal, lineWidth: lineWidth)
                    .frame(width: w, height: barHeight)
            }
        }
        .frame(width: size, height: size)
    }
}

// TumblePuns: six circles in a ring
struct TumblePunsIconView: View {
    let size: CGFloat

    var body: some View {
        let radius = size * 0.32
        let dotSize = size * 0.22
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let angle = Angle(degrees: Double(i) * 60 - 90)
                Circle()
                    .stroke(Color.mainDiagonal, lineWidth: size * 0.04)
                    .frame(width: dotSize, height: dotSize)
                    .offset(x: radius * cos(angle.radians), y: radius * sin(angle.radians))
            }
        }
        .frame(width: size, height: size)
    }
}
