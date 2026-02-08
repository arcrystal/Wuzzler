import SwiftUI

struct HomeView: View {
    let onGameSelected: (GameType) -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Daily Puzzles")
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
fileprivate struct DiagoneIconView: View {
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

// RhymeAGrams: simple triangle
fileprivate struct RhymeAGramsIconView: View {
    let size: CGFloat

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.5, y: size * 0.12))
            path.addLine(to: CGPoint(x: size * 0.88, y: size * 0.88))
            path.addLine(to: CGPoint(x: size * 0.12, y: size * 0.88))
            path.closeSubpath()
        }
        .stroke(Color.mainDiagonal, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

// TumblePuns: simple circle
fileprivate struct TumblePunsIconView: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .stroke(Color.mainDiagonal, lineWidth: 2.5)
            .frame(width: size * 0.8, height: size * 0.8)
            .frame(width: size, height: size)
    }
}
