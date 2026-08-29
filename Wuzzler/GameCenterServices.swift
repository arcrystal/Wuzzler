import SwiftUI
@preconcurrency import GameKit
import UIKit

struct GameCenterPresentation: Identifiable {
    let id = UUID()
    let viewController: UIViewController
}

struct GameCenterControllerPresenter: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

enum GameCenterAuthState: Equatable {
    case idle
    case authenticating
    case authenticated
    case unauthenticated(String)
}

@MainActor
final class GameCenterService: NSObject, ObservableObject {
    static let shared = GameCenterService()

    @Published var authState: GameCenterAuthState = .idle
    @Published var localPlayer: GKLocalPlayer = .local
    @Published var presentation: GameCenterPresentation?
    @Published var friends: [GKPlayer] = []
    @Published var friendsAuthorizationStatus: GKFriendsAuthorizationStatus?
    @Published var friendsErrorMessage: String?

    private var accessPointRequestedVisible = true

    private lazy var dashboardDelegate = GameCenterDelegateProxy { [weak self] in
        self?.presentation = nil
    }

    private var usesUITestAuthentication: Bool {
        SecurityPolicy.usesUITestAuthentication
    }

    private var usesUITestGuest: Bool {
        SecurityPolicy.usesUITestGuest
    }

    var isAuthenticated: Bool {
        usesUITestAuthentication || GKLocalPlayer.local.isAuthenticated
    }

    func authenticate() {
        if usesUITestAuthentication {
            localPlayer = .local
            authState = .authenticated
            return
        }
        if usesUITestGuest {
            authState = .unauthenticated("Game Center is optional. Sign in to use friends, rankings, and achievements.")
            return
        }

        authState = .authenticating
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                self?.handleAuthentication(viewController: viewController, error: error)
            }
        }
    }

    func retryAuthentication() {
        presentation = nil
        authenticate()
    }

    /// The system access point is useful on the app's browsing screens, but it
    /// floats above game content. Hide it while a puzzle is open so it cannot
    /// cover the board or intercept puzzle taps.
    func setAccessPointVisible(_ isVisible: Bool) {
        accessPointRequestedVisible = isVisible
        guard !usesUITestAuthentication, !usesUITestGuest else { return }
        GKAccessPoint.shared.isActive = isVisible && isAuthenticated
    }

    func refreshFriends() {
        guard isAuthenticated else { return }
        GKLocalPlayer.local.loadFriendsAuthorizationStatus { [weak self] status, error in
            Task { @MainActor in
                guard let self else { return }
                self.friendsAuthorizationStatus = status
                if let error {
                    self.friendsErrorMessage = error.localizedDescription
                }
                if status == .authorized {
                    self.loadFriends()
                } else {
                    self.friends = []
                }
            }
        }
    }

    func requestFriendsAccess() {
        guard isAuthenticated else { return }
        GKLocalPlayer.local.loadFriends { [weak self] friends, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.friendsErrorMessage = error.localizedDescription
                }
                self.friends = friends ?? []
                self.refreshFriends()
            }
        }
    }

    func showDashboard(state: GKGameCenterViewControllerState = .dashboard) {
        if usesUITestAuthentication { return }

        guard isAuthenticated else {
            authenticate()
            return
        }
        let controller = GKGameCenterViewController(state: state)
        controller.gameCenterDelegate = dashboardDelegate
        presentation = GameCenterPresentation(viewController: controller)
    }

    func showLeaderboard(_ leaderboard: WuzzlerLeaderboard, audience: LeaderboardAudience) {
        if usesUITestAuthentication { return }

        guard isAuthenticated else {
            authenticate()
            return
        }
        let scope: GKLeaderboard.PlayerScope = audience == .friends ? .friendsOnly : .global
        let controller = GKGameCenterViewController(
            leaderboardID: leaderboard.rawValue,
            playerScope: scope,
            timeScope: .today
        )
        controller.gameCenterDelegate = dashboardDelegate
        presentation = GameCenterPresentation(viewController: controller)
    }

    private func handleAuthentication(viewController: UIViewController?, error: Error?) {
        if let viewController {
            presentation = GameCenterPresentation(viewController: viewController)
            authState = .authenticating
            return
        }

        localPlayer = .local
        if GKLocalPlayer.local.isAuthenticated {
            authState = .authenticated
            presentation = nil
            configureAccessPoint()
            refreshFriends()
            Task {
                await LeaderboardService.shared.flushPendingSubmissions()
                await AchievementService.shared.flushPendingReports()
            }
        } else {
            GKAccessPoint.shared.isActive = false
            friends = []
            friendsAuthorizationStatus = nil
            authState = .unauthenticated("Game Center is unavailable. You can keep playing as a guest.")
        }
    }

    private func configureAccessPoint() {
        GKAccessPoint.shared.location = .topTrailing
        setAccessPointVisible(accessPointRequestedVisible)
    }

    private func loadFriends() {
        GKLocalPlayer.local.loadFriends { [weak self] friends, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.friendsErrorMessage = error.localizedDescription
                }
                self.friends = friends ?? []
            }
        }
    }
}

private final class GameCenterDelegateProxy: NSObject, GKGameCenterControllerDelegate {
    private let onFinish: @MainActor () -> Void

    init(onFinish: @escaping @MainActor () -> Void) {
        self.onFinish = onFinish
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in
            onFinish()
        }
    }
}

enum WuzzlerLeaderboard: String, CaseIterable, Identifiable {
    case diagoneDaily = "wuzzler.diagone.daily"
    case rhymeagramsDaily = "wuzzler.rhymeagrams.daily"
    case tumblepunsDaily = "wuzzler.tumblepuns.daily"
    case sweepDaily = "wuzzler.sweep.daily"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diagoneDaily: return "Diagone"
        case .rhymeagramsDaily: return "RhymeAGram"
        case .tumblepunsDaily: return "TumblePun"
        case .sweepDaily: return "Daily Sweep"
        }
    }

    static func daily(for game: GameType) -> WuzzlerLeaderboard {
        switch game {
        case .diagone: return .diagoneDaily
        case .rhymeAGrams: return .rhymeagramsDaily
        case .tumblePuns: return .tumblepunsDaily
        }
    }
}

enum LeaderboardAudience: String, CaseIterable, Identifiable {
    case friends
    case global

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friends: return "Friends"
        case .global: return "Global"
        }
    }
}

struct LeaderboardRow: Identifiable {
    let id: String
    let rank: Int
    let playerName: String
    let formattedScore: String
    let isLocalPlayer: Bool
}

struct PendingLeaderboardScore: Codable, Hashable {
    let leaderboardID: String
    let score: Int
    let context: Int
    let dayKey: String

    var coalescingKey: String {
        "\(leaderboardID)|\(dayKey)"
    }
}

@MainActor
final class LeaderboardService: ObservableObject {
    static let shared = LeaderboardService()

    private let pendingKey = "game_center_pending_scores_v1"
    private let submittedPrefix = "game_center_submitted_score"
    private let defaults: UserDefaults
    private let authenticationProvider: () -> Bool
    private let injectedSubmitter: ((PendingLeaderboardScore) async -> Bool)?

    init(
        defaults: UserDefaults = .standard,
        authenticationProvider: @escaping () -> Bool = { GKLocalPlayer.local.isAuthenticated },
        submitter: ((PendingLeaderboardScore) async -> Bool)? = nil
    ) {
        self.defaults = defaults
        self.authenticationProvider = authenticationProvider
        self.injectedSubmitter = submitter
    }

    static func centiseconds(from time: TimeInterval) -> Int {
        max(0, Int((time * 100).rounded()))
    }

    func submitDailySolve(game: GameType, time: TimeInterval, date: Date) {
        guard PuzzleDay.isToday(date), time > 0 else { return }
        let leaderboard = WuzzlerLeaderboard.daily(for: game)
        submit(leaderboard: leaderboard, score: Self.centiseconds(from: time), date: date)
    }

    func submitSweepIfComplete(on date: Date) {
        guard PuzzleDay.isToday(date), let times = StreakManager.dailySweepFinishTimes(on: date) else { return }
        let total = times.values.reduce(0, +)
        submit(leaderboard: .sweepDaily, score: Self.centiseconds(from: total), date: date)
    }

    func loadEntries(for leaderboard: WuzzlerLeaderboard, audience: LeaderboardAudience) async throws -> [LeaderboardRow] {
        let leaderboards = try await loadLeaderboards(ids: [leaderboard.rawValue])
        guard let board = leaderboards.first else { return [] }
        let scope: GKLeaderboard.PlayerScope = audience == .friends ? .friendsOnly : .global
        let entries = try await loadEntries(board: board, scope: scope)
        return entries.map { entry in
            LeaderboardRow(
                id: "\(entry.player.gamePlayerID)-\(entry.rank)",
                rank: entry.rank,
                playerName: entry.player.displayName,
                formattedScore: entry.formattedScore,
                isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
            )
        }
    }

    func flushPendingSubmissions() async {
        guard authenticationProvider() else { return }
        let pending = Self.coalescedPendingScores(pendingSubmissions())
        var remaining: [PendingLeaderboardScore] = []
        for score in pending {
            if hasSubmitted(score) {
                continue
            }
            let success = await submitToGameCenter(score)
            if success {
                markSubmitted(score)
            } else {
                remaining.append(score)
            }
        }
        savePending(remaining)
    }

    static func coalescedPendingScores(_ scores: [PendingLeaderboardScore]) -> [PendingLeaderboardScore] {
        var bestByDay: [String: PendingLeaderboardScore] = [:]
        for score in scores {
            if let current = bestByDay[score.coalescingKey] {
                if score.score < current.score {
                    bestByDay[score.coalescingKey] = score
                }
            } else {
                bestByDay[score.coalescingKey] = score
            }
        }
        return bestByDay.values.sorted {
            if $0.dayKey != $1.dayKey { return $0.dayKey < $1.dayKey }
            return $0.leaderboardID < $1.leaderboardID
        }
    }

    private func submit(leaderboard: WuzzlerLeaderboard, score: Int, date: Date) {
        let pending = PendingLeaderboardScore(
            leaderboardID: leaderboard.rawValue,
            score: score,
            context: PuzzleDay.leaderboardContext(for: date),
            dayKey: PuzzleDay.storageKey(for: date)
        )
        guard !hasSubmitted(pending) else { return }

        Task {
            if authenticationProvider() {
                if await submitToGameCenter(pending) {
                    markSubmitted(pending)
                } else {
                    queue(pending)
                }
            } else {
                queue(pending)
            }
        }
    }

    private func submitToGameCenter(_ pending: PendingLeaderboardScore) async -> Bool {
        if let injectedSubmitter {
            return await injectedSubmitter(pending)
        }
        return await withCheckedContinuation { continuation in
            GKLeaderboard.submitScore(
                pending.score,
                context: pending.context,
                player: GKLocalPlayer.local,
                leaderboardIDs: [pending.leaderboardID]
            ) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    private func loadLeaderboards(ids: [String]) async throws -> [GKLeaderboard] {
        try await withCheckedThrowingContinuation { continuation in
            GKLeaderboard.loadLeaderboards(IDs: ids) { leaderboards, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: leaderboards ?? [])
                }
            }
        }
    }

    private func loadEntries(board: GKLeaderboard, scope: GKLeaderboard.PlayerScope) async throws -> [GKLeaderboard.Entry] {
        try await withCheckedThrowingContinuation { continuation in
            board.loadEntries(for: scope, timeScope: .today, range: NSRange(location: 1, length: 25)) { _, entries, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: entries ?? [])
                }
            }
        }
    }

    private func queue(_ pending: PendingLeaderboardScore) {
        var pendingScores = pendingSubmissions()
        pendingScores.append(pending)
        savePending(Self.coalescedPendingScores(pendingScores))
    }

    private func pendingSubmissions() -> [PendingLeaderboardScore] {
        guard let data = defaults.data(forKey: pendingKey),
              let pending = try? JSONDecoder().decode([PendingLeaderboardScore].self, from: data) else { return [] }
        return pending
    }

    private func savePending(_ pending: [PendingLeaderboardScore]) {
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: pendingKey)
        }
    }

    private func hasSubmitted(_ pending: PendingLeaderboardScore) -> Bool {
        defaults.bool(forKey: submittedKey(for: pending))
    }

    private func markSubmitted(_ pending: PendingLeaderboardScore) {
        defaults.set(true, forKey: submittedKey(for: pending))
    }

    private func submittedKey(for pending: PendingLeaderboardScore) -> String {
        "\(submittedPrefix)_\(pending.leaderboardID)_\(pending.dayKey)"
    }
}

enum WuzzlerAchievement: String, CaseIterable {
    case firstSolve = "wuzzler.achievement.first_solve"
    case firstDailySweep = "wuzzler.achievement.first_daily_sweep"
    case streak7 = "wuzzler.achievement.streak_7"
    case streak14 = "wuzzler.achievement.streak_14"
    case streak30 = "wuzzler.achievement.streak_30"
    case firstDiagone = "wuzzler.achievement.diagone_first_solve"
    case firstRhymeAGrams = "wuzzler.achievement.rhymeagrams_first_solve"
    case firstTumblePuns = "wuzzler.achievement.tumblepuns_first_solve"

    static func firstSolve(for game: GameType) -> WuzzlerAchievement {
        switch game {
        case .diagone: return .firstDiagone
        case .rhymeAGrams: return .firstRhymeAGrams
        case .tumblePuns: return .firstTumblePuns
        }
    }
}

@MainActor
final class AchievementService {
    static let shared = AchievementService()

    private let pendingKey = "game_center_pending_achievements_v1"
    private let reportedPrefix = "game_center_reported_achievement"
    private let defaults: UserDefaults
    private let authenticationProvider: () -> Bool
    private let injectedReporter: (([WuzzlerAchievement]) async -> Bool)?

    init(
        defaults: UserDefaults = .standard,
        authenticationProvider: @escaping () -> Bool = { GKLocalPlayer.local.isAuthenticated },
        reporter: (([WuzzlerAchievement]) async -> Bool)? = nil
    ) {
        self.defaults = defaults
        self.authenticationProvider = authenticationProvider
        self.injectedReporter = reporter
    }

    func reportDailySolve(game: GameType, date: Date) {
        guard PuzzleDay.isToday(date) else { return }

        var achievements: Set<WuzzlerAchievement> = [.firstSolve, .firstSolve(for: game)]
        let info = StreakManager.streakInfo()
        let gameStreak: Int
        switch game {
        case .diagone: gameStreak = info.diagoneStreak
        case .rhymeAGrams: gameStreak = info.rhymeAGramsStreak
        case .tumblePuns: gameStreak = info.tumblePunsStreak
        }

        if gameStreak >= 7 { achievements.insert(.streak7) }
        if gameStreak >= 14 { achievements.insert(.streak14) }
        if gameStreak >= 30 { achievements.insert(.streak30) }
        if StreakManager.dailySweepFinishTimes(on: date) != nil {
            achievements.insert(.firstDailySweep)
        }

        report(Array(achievements))
    }

    func flushPendingReports() async {
        guard authenticationProvider() else { return }
        let pending = pendingAchievements()
        var remaining: [String] = []
        for id in pending {
            guard let achievement = WuzzlerAchievement(rawValue: id) else { continue }
            if await reportToGameCenter([achievement]) {
                markReported(achievement)
            } else {
                remaining.append(id)
            }
        }
        savePending(remaining)
    }

    private func report(_ achievements: [WuzzlerAchievement]) {
        let unreported = achievements.filter { !hasReported($0) }
        guard !unreported.isEmpty else { return }

        Task {
            if authenticationProvider(), await reportToGameCenter(unreported) {
                unreported.forEach(markReported)
            } else {
                queue(unreported)
            }
        }
    }

    private func reportToGameCenter(_ achievements: [WuzzlerAchievement]) async -> Bool {
        if let injectedReporter {
            return await injectedReporter(achievements)
        }
        let reports = achievements.map { achievement in
            let report = GKAchievement(identifier: achievement.rawValue)
            report.percentComplete = 100
            report.showsCompletionBanner = true
            return report
        }

        return await withCheckedContinuation { continuation in
            GKAchievement.report(reports) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    private func queue(_ achievements: [WuzzlerAchievement]) {
        var pending = pendingAchievements()
        for achievement in achievements where !pending.contains(achievement.rawValue) && !hasReported(achievement) {
            pending.append(achievement.rawValue)
        }
        savePending(pending)
    }

    private func pendingAchievements() -> [String] {
        guard let data = defaults.data(forKey: pendingKey),
              let pending = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return pending
    }

    private func savePending(_ pending: [String]) {
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: pendingKey)
        }
    }

    private func hasReported(_ achievement: WuzzlerAchievement) -> Bool {
        defaults.bool(forKey: reportedKey(for: achievement))
    }

    private func markReported(_ achievement: WuzzlerAchievement) {
        defaults.set(true, forKey: reportedKey(for: achievement))
    }

    private func reportedKey(for achievement: WuzzlerAchievement) -> String {
        "\(reportedPrefix)_\(achievement.rawValue)"
    }
}
