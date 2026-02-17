import SwiftUI

struct AppCoordinatorView: View {
    enum Route {
        case splash
        case home
        case game(GameType, Date)
    }

    @State private var route: Route = .splash

    var body: some View {
        Group {
            switch route {
            case .splash:
                SplashScreen()
                    .onAppear {
                        // Preload all puzzle JSON files in the background
                        DispatchQueue.global(qos: .userInitiated).async {
                            GameEngine.warmUp()
                            _ = RhymeAGramsPuzzleLibrary.loadPuzzleMap()
                            _ = TumblePunsPuzzleLibrary.loadPuzzleMap()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.4)) {
                                route = .home
                            }
                        }
                    }
            case .home:
                HomeView(onGameSelected: { gameType, date in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        route = .game(gameType, date)
                    }
                })
            case .game(let gameType, let date):
                GameCoordinatorView(gameType: gameType, puzzleDate: date, onBackToHome: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        route = .home
                    }
                })
            }
        }
    }
}

// MARK: - Splash Screen
struct SplashScreen: View {
    @State private var settled = false
    @State private var tileOpacities: [Double] = Array(repeating: 0, count: 7)
    @State private var sheenValues: [Double] = Array(repeating: 0, count: 7)

    var body: some View {
        ZStack {
            Color.diagoneAccent
                .ignoresSafeArea()

            WuzzlerSplashLogo(settled: settled, tileOpacities: tileOpacities, sheenValues: sheenValues)
        }
        .onAppear {
            // Phase 1: Tiles pop in one by one (staggered over ~0.7s)
            for i in 0..<7 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(i) * 0.08)) {
                    tileOpacities[i] = 1.0
                }
            }
            // Phase 2: Tiles settle into a row
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.8)) {
                settled = true
            }
            // Phase 3: Sheen wave across tiles
            let sheenStart = 1.6
            for i in 0..<7 {
                let tileDelay = sheenStart + Double(i) * 0.06
                withAnimation(.easeIn(duration: 0.12).delay(tileDelay)) {
                    sheenValues[i] = 1.0
                }
                withAnimation(.easeOut(duration: 0.18).delay(tileDelay + 0.12)) {
                    sheenValues[i] = 0.0
                }
            }
        }
    }
}

fileprivate struct WuzzlerSplashLogo: View {
    var settled: Bool
    var tileOpacities: [Double]
    var sheenValues: [Double]

    private struct TileState {
        let letter: String
        // Scattered positions (relative to center)
        let scatterX: CGFloat
        let scatterY: CGFloat
        let scatterRotation: Double
        let scatterScale: CGFloat
    }

    private let tiles: [TileState] = [
        TileState(letter: "W", scatterX: -80, scatterY: -100, scatterRotation: -25, scatterScale: 0.6),
        TileState(letter: "U", scatterX: 50,  scatterY: -120, scatterRotation: 15,  scatterScale: 0.7),
        TileState(letter: "Z", scatterX: 100, scatterY: -30,  scatterRotation: -20, scatterScale: 0.5),
        TileState(letter: "Z", scatterX: -100,scatterY: 40,   scatterRotation: 30,  scatterScale: 0.65),
        TileState(letter: "L", scatterX: -20, scatterY: 110,  scatterRotation: -10, scatterScale: 0.55),
        TileState(letter: "E", scatterX: 90,  scatterY: 80,   scatterRotation: 22,  scatterScale: 0.7),
        TileState(letter: "R", scatterX: -60, scatterY: -40,  scatterRotation: -18, scatterScale: 0.6),
    ]

    var body: some View {
        let tileSize: CGFloat = 44
        let spacing: CGFloat = 4
        let totalWidth = CGFloat(tiles.count) * tileSize + CGFloat(tiles.count - 1) * spacing
        let startX = -totalWidth / 2 + tileSize / 2

        ZStack {
            ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                let settledX = startX + CGFloat(index) * (tileSize + spacing)

                Text(tile.letter)
                    .font(.system(size: tileSize * 0.55, weight: .bold, design: .rounded))
                    .foregroundColor(.diagoneAccent)
                    .frame(width: tileSize, height: tileSize)
                    .background(
                        RoundedRectangle(cornerRadius: tileSize * 0.18, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: tileSize * 0.18, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: tileSize * 0.18, style: .continuous)
                            .fill(Color.white.opacity(index < sheenValues.count ? sheenValues[index] * 0.55 : 0))
                    )
                    .shadow(color: .black.opacity(0.25), radius: settled ? 3 : 6, x: 0, y: settled ? 2 : 4)
                    .scaleEffect(settled ? 1.0 : tile.scatterScale)
                    .rotationEffect(.degrees(settled ? 0 : tile.scatterRotation))
                    .offset(
                        x: settled ? settledX : tile.scatterX,
                        y: settled ? 0 : tile.scatterY
                    )
                    .opacity(index < tileOpacities.count ? tileOpacities[index] : 0)
            }
        }
    }
}
