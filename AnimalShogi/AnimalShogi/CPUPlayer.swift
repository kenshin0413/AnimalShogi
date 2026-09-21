import Foundation

nonisolated struct CPUPlayer: Sendable {
    let searchDepth: Int
    let allowsVariety: Bool

    init(searchDepth: Int = 4, allowsVariety: Bool = true) {
        self.searchDepth = max(1, searchDepth)
        self.allowsVariety = allowsVariety
    }

    func bestMove(in state: GameState) -> Move? {
        let moves = ordered(GameEngine.legalMoves(in: state), in: state)
        guard !moves.isEmpty else { return nil }
        let perspective = state.currentPlayer
        var bestScore = Int.min
        var bestMoves: [Move] = []
        var scoredMoves: [(move: Move, score: Int)] = []

        for move in moves {
            guard let child = GameEngine.applying(move, to: state) else { continue }
            let score = minimax(child, depth: searchDepth - 1, alpha: Int.min + 1, beta: Int.max - 1, perspective: perspective)
            scoredMoves.append((move, score))
            if score > bestScore {
                bestScore = score
                bestMoves = [move]
            } else if score == bestScore {
                bestMoves.append(move)
            }
        }
        let nearBest = scoredMoves.filter { bestScore - $0.score <= 180 }.map(\.move)
        if allowsVariety && nearBest.count > 1 && Double.random(in: 0..<1) < 0.30 {
            return nearBest.randomElement()
        }
        return bestMoves.randomElement()
    }

    private func minimax(_ state: GameState, depth: Int, alpha: Int, beta: Int, perspective: Player) -> Int {
        if depth == 0 || state.result != .playing { return evaluate(state, for: perspective) }
        let moves = ordered(GameEngine.legalMoves(in: state), in: state)
        if moves.isEmpty { return evaluate(state, for: perspective) }

        var alpha = alpha
        var beta = beta
        if state.currentPlayer == perspective {
            var value = Int.min
            for move in moves {
                guard let child = GameEngine.applying(move, to: state) else { continue }
                value = max(value, minimax(child, depth: depth - 1, alpha: alpha, beta: beta, perspective: perspective))
                alpha = max(alpha, value)
                if alpha >= beta { break }
            }
            return value
        } else {
            var value = Int.max
            for move in moves {
                guard let child = GameEngine.applying(move, to: state) else { continue }
                value = min(value, minimax(child, depth: depth - 1, alpha: alpha, beta: beta, perspective: perspective))
                beta = min(beta, value)
                if alpha >= beta { break }
            }
            return value
        }
    }

    private func evaluate(_ state: GameState, for perspective: Player) -> Int {
        switch state.result {
        case .won(let winner, _):
            let score = 100_000 - state.turnNumber
            return winner == perspective ? score : -score
        case .playing: break
        }

        var score = 0
        for (position, piece) in state.board.pieces {
            let sign = piece.owner == .cpu ? 1 : -1
            score += sign * piece.type.value * 100
            if piece.type == .lion {
                let progress = (Board.rows - 1) - abs(piece.owner.goalRow - position.row)
                score += sign * progress * 18
                if GameEngine.isLionThreatened(piece.owner, in: state) { score -= sign * 350 }
            }
        }
        for player in Player.allCases {
            let sign = player == .cpu ? 1 : -1
            for (type, count) in state.hands[player, default: [:]] {
                score += sign * type.value * count * 115
            }
        }
        if state.pendingTry == .cpu { score += 4_000 }
        if state.pendingTry == .human { score -= 4_000 }
        return perspective == .cpu ? score : -score
    }

    private func ordered(_ moves: [Move], in state: GameState) -> [Move] {
        moves.sorted { priority($0, in: state) > priority($1, in: state) }
    }

    private func priority(_ move: Move, in state: GameState) -> Int {
        var result = (state.board[move.destination]?.type.value ?? 0) * 10
        if case .board(let origin) = move.source,
           state.board[origin]?.type == .lion,
           move.destination.row == state.currentPlayer.goalRow { result += 100 }
        return result
    }
}
