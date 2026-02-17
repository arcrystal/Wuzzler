import Foundation
import SwiftUI
import Combine
import UIKit

/// Base view model for all Wuzzler games. Contains shared lifecycle logic
/// (timer, DailyMeta persistence, start/pause/resume/clear, win/incorrect
/// feedback sequences). Subclasses override template methods to plug in
/// game-specific behaviour.
@MainActor
class GameFlowViewModel: ObservableObject {
    // MARK: - Shared Published State
    @Published var started: Bool = false
    @Published var finished: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var finishTime: TimeInterval = 0
    @Published var winWaveTrigger: Int = 0
    @Published var shakeTrigger: Int = 0
    @Published var showIncorrectFeedback: Bool = false

    // MARK: - Shared Private State
    var timerCancellable: AnyCancellable?
    var startDate: Date?
    var saveWorkItem: DispatchWorkItem?

    // MARK: - Required Subclass Properties
    let storageKeyPrefix: String
    let gameType: GameType
    let puzzleDate: Date

    /// Exact time from wave trigger to last bounce settling.
    /// Subclasses should compute this from their animation parameters.
    open var winAnimationDuration: TimeInterval { 1.0 }

    /// Whether this is an archive (non-today) puzzle.
    var isArchivePuzzle: Bool {
        !Calendar.current.isDateInToday(puzzleDate)
    }

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var puzzleDateString: String {
        Self.dateKeyFormatter.string(from: puzzleDate)
    }

    var storageKey: String { "\(storageKeyPrefix)_state_\(puzzleDateString)" }

    // MARK: - DailyMeta Persistence

    struct DailyMeta: Codable {
        var started: Bool
        var finished: Bool
        var elapsedTime: TimeInterval
        var finishTime: TimeInterval
        var lastUpdated: Date
    }

    var metaKey: String {
        "\(storageKeyPrefix)_meta_\(puzzleDateString)"
    }

    func loadDailyMeta() -> DailyMeta? {
        guard let data = UserDefaults.standard.data(forKey: metaKey) else { return nil }
        return try? JSONDecoder().decode(DailyMeta.self, from: data)
    }

    func saveDailyMeta(started: Bool? = nil,
                       finished: Bool? = nil,
                       elapsedTime: TimeInterval? = nil,
                       finishTime: TimeInterval? = nil) {
        var current = loadDailyMeta() ?? DailyMeta(started: false, finished: false, elapsedTime: 0, finishTime: 0, lastUpdated: Date())
        if let s = started { current.started = s }
        if let f = finished { current.finished = f }
        if let e = elapsedTime { current.elapsedTime = e }
        if let ft = finishTime { current.finishTime = ft }
        current.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: metaKey)
        }
    }

    // MARK: - Init

    init(storageKeyPrefix: String, gameType: GameType, puzzleDate: Date = Date()) {
        self.storageKeyPrefix = storageKeyPrefix
        self.gameType = gameType
        self.puzzleDate = puzzleDate

        // Migration: if puzzleDate is today and legacy key has data but new key doesn't, migrate
        if Calendar.current.isDateInToday(puzzleDate) {
            let legacyKey = "\(storageKeyPrefix)_state"
            let newKey = "\(storageKeyPrefix)_state_\(Self.dateKeyFormatter.string(from: puzzleDate))"
            if UserDefaults.standard.data(forKey: legacyKey) != nil &&
               UserDefaults.standard.data(forKey: newKey) == nil {
                let data = UserDefaults.standard.data(forKey: legacyKey)
                UserDefaults.standard.set(data, forKey: newKey)
                UserDefaults.standard.removeObject(forKey: legacyKey)
            }
        }

        let meta = self.loadDailyMeta()
        if let meta = meta {
            self.started = meta.started
            self.finished = meta.finished
            self.elapsedTime = meta.elapsedTime
            self.finishTime = meta.finishTime
        }
    }

    // MARK: - Template Methods (override in subclasses)

    /// Called after the game transitions to started state. Reset engine, select first slot, etc.
    open func onStartGame() {}
    /// Called when the user clears the game. Reset engine and game-specific state.
    open func onClearGame() {}
    /// Called when the game is paused. Optional.
    open func onPause() {}
    /// Called when the game is resumed. Optional.
    open func onResume() {}
    /// Return true if all inputs are filled AND the engine reports solved.
    open func checkGameSolved() -> Bool { false }
    /// Called after an incorrect submission. Game-specific cleanup (e.g. clear final answer).
    open func onIncorrectAttempt() {}
    /// Encode game engine state for persistence.
    open func encodeGameState() -> Data? { nil }
    /// Restore game engine state from persisted data. Return true if successful.
    open func restoreGameState(from data: Data) -> Bool { false }

    // MARK: - Shared Game Lifecycle

    func startGame() {
        guard !started else { return }
        started = true
        startDate = Date()
        elapsedTime = 0
        onStartGame()
        saveDailyMeta(started: true, finished: false, elapsedTime: 0, finishTime: 0)
        startTimer()
    }

    func pause() {
        guard started, !finished else { return }
        stopTimer()
        saveWorkItem?.cancel()
        onPause()
        saveState()
        saveDailyMeta(elapsedTime: elapsedTime)
    }

    func resume() {
        guard started, !finished else { return }
        onResume()
        startTimer()
    }

    func clearGame() {
        stopTimer()
        saveWorkItem?.cancel()
        startDate = nil
        started = false
        finished = false
        elapsedTime = 0
        finishTime = 0
        showIncorrectFeedback = false
        onClearGame()
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: metaKey)
    }

    /// Call from subclass when user submits an answer (all fields filled).
    func submitAnswer() {
        guard !finished else { return }
        if checkGameSolved() {
            Haptics.prepare()
            finished = true
            finishTime = elapsedTime
            stopTimer()
            saveDailyMeta(started: true, finished: true, elapsedTime: elapsedTime, finishTime: finishTime)
            saveState()
            runWinSequence()
        } else {
            triggerIncorrectFeedback()
            onIncorrectAttempt()
        }
    }

    // MARK: - Win Sequence

    open func runWinSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.winWaveTrigger &+= 1
        }
        let delay = 0.05 + winAnimationDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Haptics.notify(.success)
        }
    }

    // MARK: - Incorrect Feedback

    func triggerIncorrectFeedback() {
        Haptics.notify(.warning)
        withAnimation(.easeIn(duration: 0.12)) {
            shakeTrigger += 1
            showIncorrectFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                self?.showIncorrectFeedback = false
            }
        }
    }

    // MARK: - Timer

    var elapsedTimeString: String {
        let t = finished ? finishTime : elapsedTime
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func startTimer() {
        guard timerCancellable == nil else { return }
        startDate = Date().addingTimeInterval(-elapsedTime)
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.startDate else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
    }

    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - State Persistence

    func saveState() {
        if let data = encodeGameState() {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func loadSavedState() -> Data? {
        UserDefaults.standard.data(forKey: storageKey)
    }

    func debouncedSave() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveState()
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
}
