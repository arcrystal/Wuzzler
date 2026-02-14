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
            DiagoneIconView(size: 54, color: gameType.accentColor)
        case .rhymeAGrams:
            RhymeAGramsIconView(size: 54, color: gameType.accentColor)
        case .tumblePuns:
            TumblePunsIconView(size: 54, color: gameType.accentColor)
        }
    }
}

// Diagone: 3x3 grid of filled rounded squares
struct DiagoneIconView: View {
    let size: CGFloat
    var color: Color = .diagoneAccent

    var body: some View {
        let cellSize = size * 0.26
        let gap = size * 0.07
        VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: cellSize * 0.2, style: .continuous)
                            .fill(color)
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// RhymeAGrams: filled triangle with rounded corners
struct RhymeAGramsIconView: View {
    let size: CGFloat
    var color: Color = .rhymeAGramsAccent

    var body: some View {
        let inset = size * 0.1
        Path { path in
            path.move(to: CGPoint(x: size * 0.5, y: inset))
            path.addLine(to: CGPoint(x: size - inset, y: size - inset))
            path.addLine(to: CGPoint(x: inset, y: size - inset))
            path.closeSubpath()
        }
        .fill(color)
        .frame(width: size, height: size)
    }
}

// TumblePuns: 3x3 grid of filled circles
struct TumblePunsIconView: View {
    let size: CGFloat
    var color: Color = .tumblePunsAccent

    var body: some View {
        let dotSize = size * 0.26
        let gap = size * 0.07
        VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(color)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}
