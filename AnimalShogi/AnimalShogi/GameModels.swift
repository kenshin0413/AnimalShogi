import Foundation

nonisolated enum Player: String, CaseIterable, Codable, Sendable {
    case human
    case cpu

    var opponent: Player { self == .human ? .cpu : .human }
    var forward: Int { self == .human ? -1 : 1 }
    var goalRow: Int { self == .human ? 0 : Board.rows - 1 }
    var displayName: String { self == .human ? "あなた" : "CPU" }
}

nonisolated enum PieceType: String, CaseIterable, Codable, Sendable {
    case lion, giraffe, elephant, chick, hen

    var name: String {
        switch self {
        case .lion: "きょうりゅう"
        case .giraffe: "カニ"
        case .elephant: "へび"
        case .chick: "こざかな"
        case .hen: "さかな"
        }
    }

    var symbol: String {
        switch self {
        case .lion: "🐻"
        case .giraffe: "🐶"
        case .elephant: "🐰"
        case .chick: "🐟"
        case .hen: "🐠"
        }
    }

    var capturedType: PieceType { self == .hen ? .chick : self }
    var value: Int {
        switch self {
        case .lion: 100
        case .hen: 5
        case .giraffe, .elephant: 3
        case .chick: 1
        }
    }
}

nonisolated struct Piece: Hashable, Codable, Sendable {
    var type: PieceType
    let owner: Player
}

nonisolated struct Position: Hashable, Codable, Sendable {
    let column: Int
    let row: Int

    var isOnBoard: Bool {
        (0..<Board.columns).contains(column) && (0..<Board.rows).contains(row)
    }
}

nonisolated struct Board: Equatable, Codable, Sendable {
    static let columns = 3
    static let rows = 5
    private(set) var pieces: [Position: Piece] = [:]

    subscript(position: Position) -> Piece? {
        get { pieces[position] }
        set { pieces[position] = newValue }
    }

    static var allPositions: [Position] {
        (0..<rows).flatMap { row in
            (0..<columns).map { Position(column: $0, row: row) }
        }
    }
}

nonisolated enum MoveSource: Hashable, Codable, Sendable {
    case board(Position)
    case hand(PieceType)
}

nonisolated struct Move: Hashable, Codable, Sendable {
    let source: MoveSource
    let destination: Position
}

nonisolated enum WinReason: String, Equatable, Codable, Sendable {
    case capturedLion, tryRule, noLegalMoves, repetition

    var description: String {
        switch self {
        case .capturedLion: "あいての きょうりゅうを とったよ！"
        case .tryRule: "ゴールに たどりついたよ！"
        case .noLegalMoves: "あいては もう うごけないよ！"
        case .repetition: "おなじ ばめんが 4かい つづいたよ"
        }
    }
}

nonisolated enum GameResult: Equatable, Codable, Sendable {
    case playing
    case won(Player, WinReason)
}

nonisolated struct GameState: Equatable, Codable, Sendable {
    var board: Board
    var hands: [Player: [PieceType: Int]]
    var currentPlayer: Player
    var result: GameResult
    var pendingTry: Player?
    var turnNumber: Int
    var positionOccurrences: [String: Int] = [:]

    func handCount(for player: Player, type: PieceType) -> Int {
        hands[player]?[type, default: 0] ?? 0
    }
}
