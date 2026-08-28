import SwiftUI

extension Notification.Name {
    static let gameProgressDidChange = Notification.Name("GameProgressDidChange")
}

enum MainTab: String, CaseIterable, Identifiable {
    case play
    case friends
    case me

    var id: String { rawValue }

    var title: String {
        switch self {
        case .play: return "Play"
        case .friends: return "Friends"
        case .me: return "Me"
        }
    }

    var systemImage: String {
        switch self {
        case .play: return "square.grid.2x2.fill"
        case .friends: return "person.2.fill"
        case .me: return "person.crop.circle.fill"
        }
    }
}

enum GameLaunchMode: String, Equatable {
    case daily
    case practice
}

struct GameLaunch: Identifiable, Equatable {
    let gameType: GameType
    let date: Date
    let mode: GameLaunchMode

    var id: String {
        "\(gameType.rawValue)-\(PuzzleDay.storageKey(for: date))-\(mode.rawValue)"
    }

    var countsTowardStats: Bool { mode == .daily }

    static func daily(_ gameType: GameType, date: Date = PuzzleDay.today) -> GameLaunch {
        GameLaunch(gameType: gameType, date: date, mode: .daily)
    }

    static func archive(_ gameType: GameType, date: Date) -> GameLaunch {
        let mode: GameLaunchMode = PuzzleDay.isToday(date) ? .daily : .practice
        return GameLaunch(gameType: gameType, date: date, mode: mode)
    }
}

struct MainTabView: View {
    let onGameSelected: (GameLaunch) -> Void

    @State private var selectedTab: MainTab = .play

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                persistentTab(.play) {
                    HomeView(onGameSelected: onGameSelected)
                }

                persistentTab(.friends) {
                    LeaderboardsView()
                }

                persistentTab(.me) {
                    ProfileView()
                }
            }

            WuzzlerFloatingTabBar(selection: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 6)
        }
        .background(Color.wuzzlerCanvas.ignoresSafeArea())
    }

    private func persistentTab<Content: View>(
        _ tab: MainTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
            .accessibilityHidden(selectedTab != tab)
            .zIndex(selectedTab == tab ? 1 : 0)
    }
}

private struct WuzzlerFloatingTabBar: View {
    @Binding var selection: MainTab

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 19, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selection == tab ? Color.white : Color.primary.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background {
                        if selection == tab {
                            Capsule(style: .continuous)
                                .fill(Color.diagoneAccent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .accessibilityIdentifier("main-tab-\(tab.rawValue)")
            }
        }
        .padding(6)
        .frame(maxWidth: 410)
        .background {
            Capsule(style: .continuous)
                .fill(reduceTransparency ? Color.wuzzlerTabBarSolid : Color.clear)
                .background {
                    if !reduceTransparency {
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .frame(maxWidth: .infinity)
    }
}
