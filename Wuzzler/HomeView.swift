import SwiftUI

struct HomeView: View {
    let onGameSelected: (GameType) -> Void
    @State private var showMenu = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Button { showMenu = true } label: {
                        Image(systemName: "gearshape")
                            .font(.title3.weight(.medium))
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Menu")
                    Spacer()
                    Text("Wuzzler")
                        .font(.largeTitle.weight(.bold))
                    Spacer()
                    // Balance the hamburger button width
                    Color.clear
                        .frame(width: 28, height: 28)
                }
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
        .sheet(isPresented: $showMenu) {
            MenuView()
        }
    }
}

fileprivate struct GameCard: View {
    let gameType: GameType
    let onTap: () -> Void

    private var isTodayCompleted: Bool {
        let prefix: String
        switch gameType {
        case .diagone: prefix = "diagone"
        case .rhymeAGrams: prefix = "rhymeagrams"
        case .tumblePuns: prefix = "tumblepuns"
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        let key = "\(prefix)_meta_\(fmt.string(from: Date()))"
        guard let data = UserDefaults.standard.data(forKey: key),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let finished = json["finished"] as? Bool else { return false }
        return finished
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                GameIconView(gameType: gameType)
                    .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(gameType.displayName)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.primary)

                        if isTodayCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(gameType.accentColor)
                                .font(.subheadline)
                        }
                    }

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
        .accessibilityLabel("\(gameType.displayName)\(isTodayCompleted ? ", completed" : "")")
        .accessibilityHint(gameType.description)
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
        RoundedTriangle(radius: size * 0.1)
            .fill(color)
            .frame(width: size, height: size)
    }
}

private struct RoundedTriangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.0
        let top = CGPoint(x: rect.midX, y: inset)
        let bottomRight = CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
        let bottomLeft = CGPoint(x: inset, y: rect.maxY - inset)

        var path = Path()
        path.move(to: CGPoint(x: (top.x + bottomLeft.x) / 2, y: (top.y + bottomLeft.y) / 2))
        path.addArc(tangent1End: top, tangent2End: bottomRight, radius: radius)
        path.addArc(tangent1End: bottomRight, tangent2End: bottomLeft, radius: radius)
        path.addArc(tangent1End: bottomLeft, tangent2End: top, radius: radius)
        path.closeSubpath()
        return path
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
