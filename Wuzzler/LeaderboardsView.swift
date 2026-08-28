import SwiftUI

struct LeaderboardsView: View {
    @EnvironmentObject private var gameCenter: GameCenterService

    @State private var selectedLeaderboard: WuzzlerLeaderboard = .sweepDaily
    @State private var selectedAudience: LeaderboardAudience = .friends
    @State private var rows: [LeaderboardRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var loadID: String {
        "\(selectedLeaderboard.rawValue)-\(selectedAudience.rawValue)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if gameCenter.isAuthenticated {
                        audienceControl
                        leaderboardControl
                        rankingsCard
                    } else {
                        guestCard
                    }
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
            .task(id: loadID) {
                await load(leaderboard: selectedLeaderboard, audience: selectedAudience)
            }
            .accessibilityIdentifier("friends-screen")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Friends")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Today’s fastest solves")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(gameCenter.isAuthenticated ? "Manage" : "Sign In") {
                if gameCenter.isAuthenticated {
                    gameCenter.showDashboard(state: .localPlayerFriendsList)
                } else {
                    gameCenter.retryAuthentication()
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .frame(minHeight: 44)
            .accessibilityLabel("Manage friends in Game Center")
        }
    }

    private var guestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Play as a guest")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("Daily puzzles, archives, progress, streaks, and personal bests stay available without Game Center. Sign in when you want to compare scores and play with friends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Sign in to Game Center") {
                gameCenter.retryAuthentication()
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
            .accessibilityIdentifier("friends-sign-in")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.wuzzlerSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 5)
    }

    private var audienceControl: some View {
        HStack(spacing: 4) {
            ForEach(LeaderboardAudience.allCases) { audience in
                textChoice(
                    audience.title,
                    selected: selectedAudience == audience,
                    identifier: "friends-audience-\(audience.rawValue)"
                ) {
                    selectedAudience = audience
                }
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.06), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Leaderboard audience")
    }

    private var leaderboardControl: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(WuzzlerLeaderboard.allCases) { leaderboard in
                    Button {
                        selectedLeaderboard = leaderboard
                    } label: {
                        Text(leaderboard.title)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(selectedLeaderboard == leaderboard ? Color.white : Color.primary)
                            .padding(.horizontal, 15)
                            .frame(minHeight: 44)
                            .background(
                                selectedLeaderboard == leaderboard ? Color.diagoneAccent : Color.wuzzlerSurface,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedLeaderboard == leaderboard ? .isSelected : [])
                    .accessibilityIdentifier("friends-board-\(leaderboard.rawValue)")
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Leaderboard")
    }

    private func textChoice(
        _ title: String,
        selected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Color.diagoneAccent : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private var rankingsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text(selectedLeaderboard.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                Button("Open Game Center") {
                    gameCenter.showLeaderboard(selectedLeaderboard, audience: selectedAudience)
                }
                .font(.caption.weight(.semibold))
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 18)

            Divider()

            rankingsContent
        }
        .padding(.top, 4)
        .background(Color.wuzzlerSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 5)
    }

    @ViewBuilder
    private var rankingsContent: some View {
        if isLoading {
            ProgressView("Loading rankings…")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if let errorMessage {
            VStack(spacing: 14) {
                Text("Rankings unavailable")
                    .font(.headline)
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await load(leaderboard: selectedLeaderboard, audience: selectedAudience) }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .padding(24)
        } else if rows.isEmpty {
            VStack(spacing: 9) {
                Text("No scores yet")
                    .font(.headline)
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .padding(24)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    LeaderboardRankingRow(row: row)
                    if index < rows.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .padding(.vertical, 7)
        }
    }

    private var emptyMessage: String {
        selectedAudience == .friends
            ? "Friends will appear after they complete today’s counted puzzle."
            : "Complete today’s counted puzzle to join the board."
    }

    @MainActor
    private func load(leaderboard: WuzzlerLeaderboard, audience: LeaderboardAudience) async {
        guard gameCenter.isAuthenticated else {
            rows = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let result = try await LeaderboardService.shared.loadEntries(for: leaderboard, audience: audience)
            guard !Task.isCancelled,
                  leaderboard == selectedLeaderboard,
                  audience == selectedAudience else { return }
            rows = result
        } catch {
            guard !Task.isCancelled,
                  leaderboard == selectedLeaderboard,
                  audience == selectedAudience else { return }
            rows = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct LeaderboardRankingRow: View {
    let row: LeaderboardRow

    var body: some View {
        HStack(spacing: 12) {
            Text("\(row.rank)")
                .font(.system(.headline, design: .rounded, weight: .bold).monospacedDigit())
                .foregroundStyle(row.isLocalPlayer ? Color.diagoneAccent : Color.secondary)
                .frame(width: 40, alignment: .center)

            Text(row.playerName)
                .font(.body.weight(row.isLocalPlayer ? .bold : .regular))
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(row.formattedScore)
                .font(.body.weight(row.isLocalPlayer ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(row.isLocalPlayer ? Color.primary : Color.secondary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .background(row.isLocalPlayer ? Color.diagoneAccent.opacity(0.12) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(row.rank), \(row.playerName), \(row.formattedScore)\(row.isLocalPlayer ? ", you" : "")")
    }
}
