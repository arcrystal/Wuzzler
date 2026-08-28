import SwiftUI
@preconcurrency import StoreKit
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var gameCenter: GameCenterService
    @State private var refreshToken = UUID()

    var body: some View {
        let _ = refreshToken

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Me")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))

                    identityCard
                    dailyCard
                    personalBestsCard
                    wuzzlerCard
                    feedbackCard
                }
                .frame(maxWidth: 700)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Color.wuzzlerCanvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: .gameProgressDidChange)) { _ in
                refreshToken = UUID()
            }
            .accessibilityIdentifier("me-screen")
        }
    }

    private var identityCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 58))
                .foregroundStyle(Color.diagoneAccent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(gameCenter.isAuthenticated ? gameCenter.localPlayer.displayName : "Guest Player")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .lineLimit(1)
                Text(gameCenter.isAuthenticated ? "@\(gameCenter.localPlayer.alias)" : "Local progress only")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.wuzzlerSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var dailyCard: some View {
        MeCard(title: "Daily") {
            ProfileProgressSummary()

            MeDivider()

            NavigationLink {
                StatisticsView()
            } label: {
                MeNavigationLabel(title: "Statistics", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("me-statistics")

            MeDivider()

            Button {
                if gameCenter.isAuthenticated {
                    gameCenter.showDashboard(state: .achievements)
                } else {
                    gameCenter.retryAuthentication()
                }
            } label: {
                MeNavigationLabel(
                    title: gameCenter.isAuthenticated ? "Achievements" : "Sign in to Game Center",
                    systemImage: "rosette"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("me-game-center")
        }
    }

    private var personalBestsCard: some View {
        MeCard(title: "Personal Bests") {
            ForEach(Array(GameType.allCases.enumerated()), id: \.element.id) { index, game in
                ProfileBestRow(game: game)
                if index < GameType.allCases.count - 1 {
                    MeDivider()
                }
            }
        }
    }

    private var wuzzlerCard: some View {
        MeCard(title: "Wuzzler") {
            NavigationLink {
                HowToPlayView()
            } label: {
                MeNavigationLabel(title: "How to Play", systemImage: "questionmark.circle")
            }
            .buttonStyle(.plain)

            MeDivider()

            NavigationLink {
                SettingsView()
            } label: {
                MeNavigationLabel(title: "Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
        }
    }

    private var feedbackCard: some View {
        MeCard(title: "Support") {
            Button(action: requestReview) {
                MeNavigationLabel(title: "Rate & Review", systemImage: "star")
            }
            .buttonStyle(.plain)

            MeDivider()

            Button(action: openBetaSupport) {
                MeNavigationLabel(title: "Beta Support", systemImage: "questionmark.bubble")
            }
            .buttonStyle(.plain)

            MeDivider()

            Button(action: openPrivacyPolicy) {
                MeNavigationLabel(title: "Privacy", systemImage: "hand.raised")
            }
            .buttonStyle(.plain)
        }
    }

    @MainActor
    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }

    private func openBetaSupport() {
        UIApplication.shared.open(SecurityPolicy.supportURL)
    }

    private func openPrivacyPolicy() {
        UIApplication.shared.open(SecurityPolicy.privacyURL)
    }
}

private struct MeCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)

            content
                .padding(.horizontal, 18)
        }
        .padding(.bottom, 10)
        .background(Color.wuzzlerSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 9, y: 4)
    }
}

private struct MeDivider: View {
    var body: some View {
        Divider().padding(.leading, 38)
    }
}

private struct MeNavigationLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.diagoneAccent)
                .frame(width: 26)
            Text(title)
                .foregroundStyle(Color.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

private struct ProfileProgressSummary: View {
    private var progress: StreakManager.DailyProgress { StreakManager.todayProgress() }
    private var streak: StreakManager.StreakInfo { StreakManager.streakInfo() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(progress.completedCount) of 3 complete")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(progress.allComplete ? "Daily Sweep complete" : "Keep today’s run going")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label("\(streak.combinedStreak)", systemImage: "flame.fill")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.orange)
                    .accessibilityLabel("\(streak.combinedStreak) day combined streak")
            }

            ProgressView(value: Double(progress.completedCount), total: 3)
                .tint(.diagoneAccent)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }
}

private struct ProfileBestRow: View {
    let game: GameType

    private var streak: Int {
        let info = StreakManager.streakInfo()
        switch game {
        case .diagone: return info.diagoneStreak
        case .rhymeAGrams: return info.rhymeAGramsStreak
        case .tumblePuns: return info.tumblePunsStreak
        }
    }

    private var bestTime: TimeInterval? {
        StreakManager.personalBestTime(game: game)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: game.iconSystemName)
                .foregroundStyle(game.accentColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.displayName)
                    .font(.body.weight(.medium))
                Text(streak > 0 ? "\(streak) day streak" : "No active streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(bestTime.map(Self.formatTime) ?? "–")
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(bestTime == nil ? .secondary : .primary)
        }
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct FriendsView: View {
    @EnvironmentObject private var gameCenter: GameCenterService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch gameCenter.friendsAuthorizationStatus {
                case .authorized:
                    if gameCenter.friends.isEmpty {
                        friendsMessage(
                            title: "No Wuzzler friends yet",
                            message: "Manage friends in Game Center to compare daily scores."
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(gameCenter.friends.enumerated()), id: \.element.gamePlayerID) { index, player in
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(player.displayName).font(.body.weight(.medium))
                                        Text("@\(player.alias)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .frame(minHeight: 58)
                                if index < gameCenter.friends.count - 1 { Divider() }
                            }
                        }
                        .padding(.horizontal, 18)
                        .background(Color.wuzzlerSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                case .denied, .restricted:
                    friendsMessage(
                        title: "Friends are unavailable",
                        message: "Manage friend permissions and your friend list in Game Center."
                    )
                case .notDetermined:
                    Button("Allow Friends") { gameCenter.requestFriendsAccess() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 180)
                case .none:
                    ProgressView("Loading friends…")
                        .frame(maxWidth: .infinity, minHeight: 180)
                @unknown default:
                    friendsMessage(
                        title: "Friends are unavailable",
                        message: "Manage friend permissions and your friend list in Game Center."
                    )
                }
            }
            .padding(20)
        }
        .background(Color.wuzzlerCanvas.ignoresSafeArea())
        .navigationTitle("Manage Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Game Center") {
                    gameCenter.showDashboard(state: .localPlayerFriendsList)
                }
            }
        }
        .onAppear { gameCenter.refreshFriends() }
    }

    private func friendsMessage(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            Button("Manage Friends in Game Center") {
                gameCenter.showDashboard(state: .localPlayerFriendsList)
            }
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.wuzzlerSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
