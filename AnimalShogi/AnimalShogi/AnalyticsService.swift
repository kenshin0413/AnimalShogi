import Foundation
import FirebaseAnalytics

/// Centralizes event names and parameters so analytics stays independent
/// from the game engine and can be changed without touching game rules.
enum AnalyticsService {
    static func gameStarted(difficulty: String, startingPlayer: Player, sideSetting: String) {
        Analytics.logEvent("game_start", parameters: [
            "difficulty": difficulty,
            "starting_player": startingPlayer.rawValue,
            "side_setting": sideSetting
        ])
        Analytics.setUserProperty(difficulty, forName: "cpu_difficulty")
        Analytics.setUserProperty(sideSetting, forName: "starting_side")
    }

    static func gameEnded(winner: Player, reason: WinReason, turns: Int, difficulty: String) {
        Analytics.logEvent("game_end", parameters: [
            "winner": winner.rawValue,
            "reason": reason.rawValue,
            "turns": turns,
            "difficulty": difficulty
        ])
    }

    static func moveMade(player: Player, move: Move, captured: Bool, promoted: Bool, turn: Int) {
        let source: String
        switch move.source {
        case .board: source = "board"
        case .hand: source = "hand"
        }
        Analytics.logEvent("move_made", parameters: [
            "player": player.rawValue,
            "source": source,
            "captured": captured ? 1 : 0,
            "promoted": promoted ? 1 : 0,
            "turn": turn
        ])
    }

    static func hintRequested(turn: Int) {
        Analytics.logEvent("hint_requested", parameters: ["turn": turn])
    }

    static func undoUsed(turn: Int) {
        Analytics.logEvent("undo_used", parameters: ["turn": turn])
    }

    static func tutorialStarted(source: String) {
        Analytics.logEvent("tutorial_start", parameters: ["source": source])
    }

    static func tutorialCompleted() {
        Analytics.logEvent("tutorial_complete", parameters: nil)
    }

    static func tutorialSkipped(step: Int) {
        Analytics.logEvent("tutorial_skip", parameters: ["step": step])
    }

    static func appOpenAdEvent(_ name: String, errorCode: Int? = nil) {
        var parameters: [String: Any] = [:]
        if let errorCode {
            parameters["error_code"] = errorCode
        }
        Analytics.logEvent(name, parameters: parameters.isEmpty ? nil : parameters)
    }

    static func appUpdateEvent(_ name: String, storeVersion: String) {
        Analytics.logEvent(name, parameters: ["store_version": storeVersion])
    }
}
