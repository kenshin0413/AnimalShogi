import SwiftUI
import Combine
import AudioToolbox
import UIKit

@MainActor
final class GameViewModel: ObservableObject {
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "やさしい"
        case normal = "ふつう"
        case hard = "むずかしい"
        var id: Self { self }
        var depth: Int { switch self { case .easy: 2; case .normal: 4; case .hard: 5 } }
    }

    enum StartingSide: String, CaseIterable, Identifiable {
        case first = "あなたから"
        case second = "CPUから"
        case random = "おまかせ"
        var id: Self { self }
        var detail: String {
            switch self { case .first: "さいしょに うごかす"; case .second: "CPUが さき"; case .random: "まいかい かわる" }
        }
        var icon: String {
            switch self { case .first: "1.circle.fill"; case .second: "2.circle.fill"; case .random: "shuffle" }
        }
    }

    @Published private(set) var state = GameEngine.initialState()
    @Published private(set) var isCPUThinking = false
    @Published private(set) var isFindingHint = false
    @Published private(set) var hintedMove: Move?
    @Published private(set) var lastMove: Move?
    @Published var selectedSource: MoveSource?
    @Published var difficulty: Difficulty { didSet { defaults.set(difficulty.rawValue, forKey: "difficulty") } }
    @Published var startingSide: StartingSide { didSet { defaults.set(startingSide.rawValue, forKey: "startingSide") } }
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: "soundEnabled") } }
    @Published var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: "hapticsEnabled") } }
    @Published var animationsEnabled: Bool { didSet { defaults.set(animationsEnabled, forKey: "animationsEnabled") } }
    @Published private(set) var gamesPlayed: Int
    @Published private(set) var wins: Int
    @Published private(set) var losses: Int
    @Published private(set) var currentStreak: Int
    @Published private(set) var bestStreak: Int

    private let defaults = UserDefaults.standard
    private var cpuTask: Task<Void, Never>?
    private var hintTask: Task<Void, Never>?
    private var undoStack: [GameState] = []
    private var gameID = UUID()

    init() {
        let defaults = UserDefaults.standard
        difficulty = Difficulty(rawValue: defaults.string(forKey: "difficulty") ?? "") ?? .normal
        startingSide = StartingSide(rawValue: defaults.string(forKey: "startingSide") ?? "") ?? .first
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
        animationsEnabled = defaults.object(forKey: "animationsEnabled") as? Bool ?? true
        gamesPlayed = defaults.integer(forKey: "gamesPlayed")
        wins = defaults.integer(forKey: "wins")
        losses = defaults.integer(forKey: "losses")
        currentStreak = defaults.integer(forKey: "currentStreak")
        bestStreak = defaults.integer(forKey: "bestStreak")
    }

    var legalDestinations: Set<Position> {
        guard let selectedSource else { return [] }
        return GameEngine.legalDestinations(for: selectedSource, in: state)
    }

    var canInteract: Bool {
        state.result == .playing && state.currentPlayer == .human && !isCPUThinking && !isFindingHint
    }

    var canUndo: Bool { !undoStack.isEmpty && !isCPUThinking }

    func tapSquare(_ position: Position) {
        guard canInteract else { return }
        if let selectedSource,
           legalDestinations.contains(position) {
            play(Move(source: selectedSource, destination: position))
            return
        }
        if let piece = state.board[position], piece.owner == .human {
            selectedSource = .board(position)
            hintedMove = nil
        } else {
            selectedSource = nil
            hintedMove = nil
        }
    }

    func selectHandPiece(_ type: PieceType) {
        guard canInteract, state.handCount(for: .human, type: type) > 0 else { return }
        let source = MoveSource.hand(type)
        selectedSource = selectedSource == source ? nil : source
        hintedMove = nil
        lastMove = nil
    }

    func restart() {
        resetGame(beginCPUIfNeeded: true)
    }

    func resetForHome() {
        resetGame(beginCPUIfNeeded: false)
    }

    private func resetGame(beginCPUIfNeeded: Bool) {
        cpuTask?.cancel()
        hintTask?.cancel()
        gameID = UUID()
        let humanStarts: Bool
        switch startingSide {
        case .first: humanStarts = true
        case .second: humanStarts = false
        case .random: humanStarts = Bool.random()
        }
        state = GameEngine.initialState(firstPlayer: humanStarts ? .human : .cpu)
        selectedSource = nil
        isCPUThinking = false
        isFindingHint = false
        hintedMove = nil
        lastMove = nil
        undoStack.removeAll()
        if beginCPUIfNeeded {
            AnalyticsService.gameStarted(
                difficulty: difficulty.rawValue,
                startingPlayer: humanStarts ? .human : .cpu,
                sideSetting: startingSide.rawValue
            )
        }
        if beginCPUIfNeeded && !humanStarts { requestCPUMove() }
    }

    func undoTurn() {
        guard canUndo, let previous = undoStack.popLast() else { return }
        AnalyticsService.undoUsed(turn: state.turnNumber)
        cpuTask?.cancel(); hintTask?.cancel(); gameID = UUID()
        state = previous
        selectedSource = nil; hintedMove = nil
        lastMove = nil
        isCPUThinking = false; isFindingHint = false
    }

    func requestHint() {
        guard canInteract, !isFindingHint else { return }
        AnalyticsService.hintRequested(turn: state.turnNumber)
        isFindingHint = true
        let snapshot = state
        hintTask = Task {
            let move = await Task.detached(priority: .userInitiated) {
                CPUPlayer(searchDepth: 5, allowsVariety: false).bestMove(in: snapshot)
            }.value
            guard !Task.isCancelled, state == snapshot else { isFindingHint = false; return }
            hintedMove = move
            selectedSource = move?.source
            isFindingHint = false
        }
    }

    private func play(_ move: Move) {
        if state.currentPlayer == .human { undoStack.append(state) }
        let previous = state
        guard let next = GameEngine.applying(move, to: state) else { return }
        state = next
        lastMove = move
        selectedSource = nil
        hintedMove = nil
        provideFeedback(for: move, previous: previous, next: next)
        recordResultIfNeeded(previous: previous, next: next)
        if next.result == .playing && next.currentPlayer == .cpu { requestCPUMove() }
    }

    private func requestCPUMove() {
        isCPUThinking = true
        let snapshot = state
        let expectedGameID = gameID
        let cpu = CPUPlayer(searchDepth: difficulty.depth)
        cpuTask = Task {
            let move = await Task.detached(priority: .userInitiated) {
                cpu.bestMove(in: snapshot)
            }.value
            guard !Task.isCancelled, expectedGameID == gameID else { return }
            isCPUThinking = false
            let previous = state
            guard let move, let next = GameEngine.applying(move, to: previous) else { return }
            state = next
            lastMove = move
            provideFeedback(for: move, previous: previous, next: next)
            recordResultIfNeeded(previous: previous, next: next)
        }
    }

    private func provideFeedback(for move: Move, previous: GameState, next: GameState) {
        let captured = previous.board[move.destination] != nil
        let promoted: Bool = {
            guard case .board(let origin) = move.source else { return false }
            return previous.board[origin]?.type == .chick && next.board[move.destination]?.type == .hen
        }()
        AnalyticsService.moveMade(
            player: previous.currentPlayer,
            move: move,
            captured: captured,
            promoted: promoted,
            turn: previous.turnNumber
        )
        if soundEnabled {
            AudioServicesPlaySystemSound(next.result == .playing ? (captured ? 1105 : (promoted ? 1025 : 1104)) : 1025)
        }
        guard hapticsEnabled else { return }
        if next.result != .playing {
            UINotificationFeedbackGenerator().notificationOccurred({ if case .won(.human, _) = next.result { return .success }; return .error }())
        } else {
            UIImpactFeedbackGenerator(style: captured || promoted ? .medium : .light).impactOccurred()
        }
    }

    private func recordResultIfNeeded(previous: GameState, next: GameState) {
        guard previous.result == .playing, case .won(let winner, let reason) = next.result else { return }
        AnalyticsService.gameEnded(
            winner: winner,
            reason: reason,
            turns: next.turnNumber,
            difficulty: difficulty.rawValue
        )
        gamesPlayed += 1
        if winner == .human {
            wins += 1; currentStreak += 1; bestStreak = max(bestStreak, currentStreak)
        } else {
            losses += 1; currentStreak = 0
        }
        defaults.set(gamesPlayed, forKey: "gamesPlayed")
        defaults.set(wins, forKey: "wins")
        defaults.set(losses, forKey: "losses")
        defaults.set(currentStreak, forKey: "currentStreak")
        defaults.set(bestStreak, forKey: "bestStreak")
    }
}
