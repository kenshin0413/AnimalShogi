import Foundation

private var checks = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else {
        fputs("FAILED: \(message)\n", stderr)
        exit(1)
    }
}

private func state(board: Board, current: Player = .human,
                   hands: [Player: [PieceType: Int]] = [.human: [:], .cpu: [:]],
                   pendingTry: Player? = nil) -> GameState {
    GameState(board: board, hands: hands, currentPlayer: current, result: .playing,
              pendingTry: pendingTry, turnNumber: 1)
}

private func board(_ entries: [(Int, Int, PieceType, Player)]) -> Board {
    var result = Board()
    for (column, row, type, owner) in entries {
        result[Position(column: column, row: row)] = Piece(type: type, owner: owner)
    }
    return result
}

let initial = GameEngine.initialState()
expect(initial.board.pieces.count == 8, "initial setup has eight pieces")
expect(initial.currentPlayer == .human, "human moves first")
let cpuFirst = GameEngine.initialState(firstPlayer: .cpu)
expect(cpuFirst.currentPlayer == .cpu, "CPU can be selected as first player")
expect(CPUPlayer(searchDepth: 2).bestMove(in: cpuFirst) != nil, "CPU can make the opening move")
expect(Board.rows == 5, "board has five rows")
expect(initial.board[Position(column: 0, row: 0)]?.type == .giraffe, "CPU giraffe starts top-left")
expect(initial.board[Position(column: 1, row: 0)]?.type == .elephant, "CPU elephant starts top-center")
expect(initial.board[Position(column: 2, row: 0)]?.type == .lion, "CPU lion starts top-right")
expect(initial.board[Position(column: 2, row: 1)] == Piece(type: .chick, owner: .cpu), "CPU chick protects lion")
expect(initial.board[Position(column: 0, row: 3)] == Piece(type: .chick, owner: .human), "human setup is rotated")
expect(GameEngine.legalMoves(in: initial).allSatisfy { $0.destination.isOnBoard }, "all moves stay on board")

let movementCases: [(PieceType, Int)] = [(.lion, 8), (.giraffe, 4), (.elephant, 4), (.chick, 1), (.hen, 6)]
for (type, expectedCount) in movementCases {
    let origin = Position(column: 1, row: 1)
    var movementBoard = Board()
    movementBoard[origin] = Piece(type: type, owner: .human)
    if type != .lion {
        movementBoard[Position(column: 0, row: 3)] = Piece(type: .lion, owner: .human)
    }
    let destinations = GameEngine.legalDestinations(for: .board(origin), in: state(board: movementBoard))
    expect(destinations.count == expectedCount, "\(type.rawValue) movement directions")
}

let captureBoard = board([(0, 3, .lion, .human), (2, 0, .lion, .cpu),
                          (1, 2, .giraffe, .human), (1, 1, .hen, .cpu)])
let captureState = state(board: captureBoard)
let capture = Move(source: .board(Position(column: 1, row: 2)), destination: Position(column: 1, row: 1))
let afterCapture = GameEngine.applying(capture, to: captureState)!
expect(afterCapture.handCount(for: .human, type: .chick) == 1, "captured hen demotes to chick in hand")
expect(afterCapture.board[Position(column: 1, row: 1)]?.owner == .human, "capture moves piece")

let promotionBoard = board([(2, 3, .lion, .human), (2, 0, .lion, .cpu), (0, 1, .chick, .human)])
let promotion = Move(source: .board(Position(column: 0, row: 1)), destination: Position(column: 0, row: 0))
let promoted = GameEngine.applying(promotion, to: state(board: promotionBoard))!
expect(promoted.board[Position(column: 0, row: 0)]?.type == .hen, "chick promotes on last row")

let handState = state(board: board([(1, 3, .lion, .human), (1, 0, .lion, .cpu)]),
                      hands: [.human: [.chick: 1], .cpu: [:]])
let chickDrops = GameEngine.legalMoves(in: handState).filter { $0.source == .hand(.chick) }
expect(!chickDrops.isEmpty, "hand piece can be dropped")
expect(chickDrops.contains { $0.destination.row == 0 }, "chick can drop on last row")
expect(chickDrops.allSatisfy { handState.board[$0.destination] == nil }, "drops only use empty squares")
let lastRowDrop = chickDrops.first { $0.destination.row == 0 }!
let afterLastRowDrop = GameEngine.applying(lastRowDrop, to: handState)!
expect(afterLastRowDrop.board[lastRowDrop.destination]?.type == .chick,
       "chick dropped on last row stays unpromoted")

let winBoard = board([(0, 3, .lion, .human), (1, 0, .lion, .cpu), (1, 1, .giraffe, .human)])
let lionCapture = Move(source: .board(Position(column: 1, row: 1)), destination: Position(column: 1, row: 0))
expect(GameEngine.applying(lionCapture, to: state(board: winBoard))?.result == .won(.human, .capturedLion),
       "capturing lion wins immediately")
expect(CPUPlayer(searchDepth: 3, allowsVariety: false).bestMove(in: state(board: winBoard)) == lionCapture,
       "human hint chooses an immediate winning move")

let checkBoard = board([(1, 3, .lion, .human), (1, 2, .giraffe, .cpu),
                        (0, 0, .lion, .cpu), (2, 1, .elephant, .human)])
let checked = state(board: checkBoard)
expect(GameEngine.legalMoves(in: checked).allSatisfy { move in
    guard let next = GameEngine.applying(move, to: checked) else { return false }
    return !GameEngine.isLionThreatened(.human, in: next)
}, "legal moves never leave lion in check")
let irrelevantMove = Move(source: .board(Position(column: 2, row: 1)), destination: Position(column: 1, row: 0))
expect(!GameEngine.legalMoves(in: checked).contains(irrelevantMove), "unrelated move is rejected while in check")

let tryBoard = board([(1, 1, .lion, .human), (2, 3, .lion, .cpu)])
let enterGoal = Move(source: .board(Position(column: 1, row: 1)), destination: Position(column: 1, row: 0))
let tryPending = GameEngine.applying(enterGoal, to: state(board: tryBoard))!
expect(tryPending.pendingTry == .human && tryPending.result == .playing, "try waits for opponent reply")
let reply = GameEngine.legalMoves(in: tryPending).first!
expect(GameEngine.applying(reply, to: tryPending)?.result == .won(.human, .tryRule), "surviving reply completes try")

let cpuState: GameState = {
    var value = initial
    value.currentPlayer = .cpu
    return value
}()
let cpuMove = CPUPlayer(searchDepth: 4).bestMove(in: cpuState)
expect(cpuMove != nil && GameEngine.legalMoves(in: cpuState).contains(cpuMove!), "CPU finds a legal move")

let repeatingMove = GameEngine.legalMoves(in: initial).first!
let repeatedPosition = GameEngine.applying(repeatingMove, to: initial)!
var repetitionReady = initial
repetitionReady.positionOccurrences[GameEngine.repetitionKey(for: repeatedPosition)] = 3
let repetitionLoss = GameEngine.applying(repeatingMove, to: repetitionReady)
expect(repetitionLoss?.result == .won(.cpu, .repetition), "player creating fourth occurrence loses")

var finishedGames = 0
for _ in 0..<10 {
    var simulation = GameEngine.initialState()
    for _ in 0..<3_000 where simulation.result == .playing {
        guard let move = GameEngine.legalMoves(in: simulation).randomElement(),
              let next = GameEngine.applying(move, to: simulation) else { break }
        simulation = next
    }
    if simulation.result != .playing { finishedGames += 1 }
}
expect(finishedGames == 10, "complete games reach a result without crashing")

print("PASS: \(checks) rule checks")
