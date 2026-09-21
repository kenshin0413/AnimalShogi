import Foundation

nonisolated enum GameEngine {
    static func initialState(firstPlayer: Player = .human) -> GameState {
        var board = Board()
        board[Position(column: 0, row: 0)] = Piece(type: .giraffe, owner: .cpu)
        board[Position(column: 1, row: 0)] = Piece(type: .elephant, owner: .cpu)
        board[Position(column: 2, row: 0)] = Piece(type: .lion, owner: .cpu)
        board[Position(column: 2, row: 1)] = Piece(type: .chick, owner: .cpu)
        board[Position(column: 0, row: 3)] = Piece(type: .chick, owner: .human)
        board[Position(column: 0, row: 4)] = Piece(type: .lion, owner: .human)
        board[Position(column: 1, row: 4)] = Piece(type: .elephant, owner: .human)
        board[Position(column: 2, row: 4)] = Piece(type: .giraffe, owner: .human)
        var state = GameState(board: board, hands: [.human: [:], .cpu: [:]], currentPlayer: firstPlayer,
                              result: .playing, pendingTry: nil, turnNumber: 1)
        state.positionOccurrences[repetitionKey(for: state)] = 1
        return state
    }

    static func repetitionKey(for state: GameState) -> String {
        var components = Board.allPositions.map { position -> String in
            guard let piece = state.board[position] else { return "0" }
            let ownerCode = piece.owner == .human ? "h" : "c"
            return ownerCode + piece.type.rawValue.prefix(1)
        }
        for player in Player.allCases {
            for type in [PieceType.giraffe, .elephant, .chick] {
                components.append("\(player.rawValue.prefix(1))\(type.rawValue.prefix(1))\(state.handCount(for: player, type: type))")
            }
        }
        components.append(state.currentPlayer.rawValue)
        return components.joined(separator: ",")
    }

    static func legalMoves(in state: GameState, for requestedPlayer: Player? = nil) -> [Move] {
        guard state.result == .playing else { return [] }
        let player = requestedPlayer ?? state.currentPlayer
        var moves: [Move] = []

        for (position, piece) in state.board.pieces where piece.owner == player {
            for destination in pseudoDestinations(for: piece, from: position, on: state.board) {
                let move = Move(source: .board(position), destination: destination)
                if leavesLionSafe(move, for: player, in: state) { moves.append(move) }
            }
        }

        for (type, count) in state.hands[player, default: [:]] where count > 0 {
            for destination in Board.allPositions where state.board[destination] == nil {
                let move = Move(source: .hand(type), destination: destination)
                if leavesLionSafe(move, for: player, in: state) { moves.append(move) }
            }
        }
        return moves
    }

    static func legalDestinations(for source: MoveSource, in state: GameState) -> Set<Position> {
        Set(legalMoves(in: state).filter { $0.source == source }.map(\.destination))
    }

    static func applying(_ move: Move, to state: GameState) -> GameState? {
        guard legalMoves(in: state).contains(move) else { return nil }
        return applyUnchecked(move, to: state, mover: state.currentPlayer, resolveGame: true)
    }

    static func isLionThreatened(_ player: Player, in state: GameState) -> Bool {
        guard let lion = state.board.pieces.first(where: {
            $0.value.owner == player && $0.value.type == .lion
        })?.key else { return true }
        return isAttacked(lion, by: player.opponent, on: state.board)
    }

    private static func leavesLionSafe(_ move: Move, for player: Player, in state: GameState) -> Bool {
        let next = applyUnchecked(move, to: state, mover: player, resolveGame: false)
        return !isLionThreatened(player, in: next)
    }

    private static func applyUnchecked(_ move: Move, to state: GameState, mover: Player, resolveGame: Bool) -> GameState {
        var next = state
        let movingPiece: Piece
        switch move.source {
        case .board(let origin):
            guard let piece = next.board[origin], piece.owner == mover else { return state }
            movingPiece = piece
            next.board[origin] = nil
        case .hand(let type):
            guard next.handCount(for: mover, type: type) > 0 else { return state }
            movingPiece = Piece(type: type, owner: mover)
            next.hands[mover, default: [:]][type, default: 0] -= 1
        }

        let captured = next.board[move.destination]
        if let captured, captured.type != .lion {
            next.hands[mover, default: [:]][captured.type.capturedType, default: 0] += 1
        }
        var placed = movingPiece
        // A chick promotes only by moving onto the last row. A chick dropped
        // directly there stays unpromoted and cannot move forward.
        if case .board = move.source, placed.type == .chick && move.destination.row == mover.goalRow {
            placed.type = .hen
        }
        next.board[move.destination] = placed
        next.turnNumber += 1
        guard resolveGame else { return next }

        if captured?.type == .lion {
            next.result = .won(mover, .capturedLion)
            next.pendingTry = nil
            return next
        }
        if let pending = state.pendingTry, pending == mover.opponent {
            next.result = .won(pending, .tryRule)
            next.pendingTry = nil
            return next
        }
        if placed.type == .lion && move.destination.row == mover.goalRow { next.pendingTry = mover }

        next.currentPlayer = mover.opponent
        let key = repetitionKey(for: next)
        let occurrence = state.positionOccurrences[key, default: 0] + 1
        next.positionOccurrences[key] = occurrence
        if occurrence >= 4 {
            next.result = .won(mover.opponent, .repetition)
            return next
        }
        if legalMoves(in: next).isEmpty { next.result = .won(mover, .noLegalMoves) }
        return next
    }

    private static func pseudoDestinations(for piece: Piece, from origin: Position, on board: Board) -> [Position] {
        movementOffsets(for: piece).compactMap { dx, dy in
            let destination = Position(column: origin.column + dx, row: origin.row + dy)
            guard destination.isOnBoard, board[destination]?.owner != piece.owner else { return nil }
            return destination
        }
    }

    private static func movementOffsets(for piece: Piece) -> [(Int, Int)] {
        let forward = piece.owner.forward
        switch piece.type {
        case .lion: return [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
        case .giraffe: return [(0, -1), (-1, 0), (1, 0), (0, 1)]
        case .elephant: return [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        case .chick: return [(0, forward)]
        case .hen: return [(-1, forward), (0, forward), (1, forward), (-1, 0), (1, 0), (0, -forward)]
        }
    }

    private static func isAttacked(_ position: Position, by attacker: Player, on board: Board) -> Bool {
        board.pieces.contains { origin, piece in
            piece.owner == attacker && pseudoDestinations(for: piece, from: origin, on: board).contains(position)
        }
    }
}
