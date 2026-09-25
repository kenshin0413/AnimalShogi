import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var game = GameViewModel()
    @State private var showingRules = ProcessInfo.processInfo.arguments.contains("-showRules")
    @State private var showingSettings = ProcessInfo.processInfo.arguments.contains("-showSettings")
    @State private var showingStats = ProcessInfo.processInfo.arguments.contains("-showStats")
    @State private var showingExitConfirmation = false
    @State private var showingInteractiveTutorial = false
    @State private var showingOnlinePlay = ProcessInfo.processInfo.arguments.contains("-showOnline")
    @State private var availableUpdate: AppUpdate?
    @State private var showingUpdateAlert = false
    @AppStorage("hasSeenInteractiveTutorial") private var hasSeenInteractiveTutorial = false
    @State private var isPlaying = ProcessInfo.processInfo.arguments.contains("-startGame")

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MeadowBackground()
                if isPlaying {
                    VStack(spacing: 8) {
                        header
                        status
                        HandView(player: .cpu, state: game.state, selectedSource: game.selectedSource) { _ in }
                        GameBoardView(game: game)
                            .frame(maxWidth: min(proxy.size.width - 16, 390))
                            .animation(game.animationsEnabled ? .spring(response: 0.34, dampingFraction: 0.72) : nil, value: game.state.turnNumber)
                            .overlay {
                                if game.isFindingHint {
                                    HStack(spacing: 10) {
                                        ProgressView().controlSize(.regular).tint(Color(red: 0.68, green: 0.20, blue: 0.17))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("おすすめを").font(.system(size: 15, weight: .bold, design: .rounded))
                                            Text("考えています…").font(.system(size: 17, weight: .black, design: .rounded))
                                        }
                                    }
                                    .foregroundStyle(Color(red: 0.60, green: 0.18, blue: 0.16))
                                    .padding(.horizontal, 20).padding(.vertical, 14)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.9), lineWidth: 1.5))
                                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                                }
                            }
                        HandView(player: .human, state: game.state, selectedSource: game.selectedSource) { game.selectHandPiece($0) }
                        actionBar
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    HomeView(start: { game.restart(); withAnimation(.easeInOut(duration: 0.28)) { isPlaying = true } },
                             startOnline: { showingOnlinePlay = true },
                             showTutorial: {
                                 AnalyticsService.tutorialStarted(source: "home")
                                 showingInteractiveTutorial = true
                             },
                             showSettings: { showingSettings = true },
                             showStats: { showingStats = true })
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                if isPlaying, case .won(let winner, let reason) = game.state.result {
                    GameOverOverlay(winner: winner, reason: reason, restart: game.restart) {
                        game.resetForHome()
                        withAnimation(.easeInOut(duration: 0.25)) { isPlaying = false }
                    }
                }
            }
            .preferredColorScheme(.light)
            .sheet(isPresented: $showingRules) { RulesSheet() }
            .sheet(isPresented: $showingSettings) { DifficultySheet(game: game) }
            .sheet(isPresented: $showingStats) { StatsSheet(game: game) }
            .fullScreenCover(isPresented: $showingInteractiveTutorial) {
                InteractiveTutorialView {
                    hasSeenInteractiveTutorial = true
                    showingInteractiveTutorial = false
                }
            }
            .fullScreenCover(isPresented: $showingOnlinePlay) { OnlinePlayView() }
            .confirmationDialog("ゲームを やめる？", isPresented: $showingExitConfirmation, titleVisibility: .visible) {
                Button("ホームへ戻る", role: .destructive) {
                    game.resetForHome()
                    withAnimation(.easeInOut(duration: 0.25)) { isPlaying = false }
                }
                Button("まだ遊ぶ", role: .cancel) {}
            } message: { Text("今のゲームは 終わりになるよ") }
            .alert("あたらしいバージョンが あるよ", isPresented: $showingUpdateAlert, presenting: availableUpdate) { update in
                Button("アップデート") {
                    AnalyticsService.appUpdateEvent("app_update_opened", storeVersion: update.storeVersion)
                    UIApplication.shared.open(update.storeURL)
                }
                Button("あとで", role: .cancel) {
                    AnalyticsService.appUpdateEvent("app_update_later", storeVersion: update.storeVersion)
                }
            } message: { _ in
                Text("もっと遊びやすくなったよ。App Storeでアップデートしよう！")
            }
            .onAppear {
                let forceTutorial = ProcessInfo.processInfo.arguments.contains("-showTutorial")
                if (forceTutorial || !hasSeenInteractiveTutorial) && !isPlaying && !showingRules && !showingSettings && !showingStats {
                    AnalyticsService.tutorialStarted(source: forceTutorial ? "preview" : "first_launch")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { showingInteractiveTutorial = true }
                }
            }
            .task {
                // 起動広告や初回の操作体験に重ならないよう、ホームが落ち着いてから確認する。
                try? await Task.sleep(for: .seconds(4))
                guard hasSeenInteractiveTutorial, !isPlaying else { return }
                guard let update = await AppUpdateChecker.check() else { return }
                availableUpdate = update
                showingUpdateAlert = true
                AnalyticsService.appUpdateEvent("app_update_available", storeVersion: update.storeVersion)
            }
        }
    }

    private var header: some View {
        HStack {
            Button { showingExitConfirmation = true } label: {
                Image(systemName: "house.fill").frame(width: 34, height: 34)
                    .background(.white.opacity(0.9), in: Circle())
            }
            Spacer()
            VStack(spacing: -2) {
                Text("いきものしょうぎ").font(.system(size: 21, weight: .black, design: .rounded))
            }.foregroundStyle(Color(red: 0.56, green: 0.18, blue: 0.16))
            Spacer()
            Button { showingRules = true } label: {
                Image(systemName: "questionmark").frame(width: 34, height: 34)
                    .background(.white.opacity(0.9), in: Circle())
            }
        }
        .font(.system(size: 15, weight: .bold)).foregroundStyle(Color(red: 0.63, green: 0.20, blue: 0.19))
        .frame(maxWidth: 390)
    }

    @ViewBuilder private var status: some View {
        switch game.state.result {
        case .playing:
            HStack(spacing: 7) {
                if game.isCPUThinking || game.isFindingHint { ProgressView().controlSize(.small) }
                Circle().fill(game.hintedMove != nil ? Color.yellow : (game.isCPUThinking || game.isFindingHint ? Color.orange : Color.green)).frame(width: 8, height: 8)
                Text(game.isFindingHint ? "おすすめを 考えています…" : (game.hintedMove != nil ? "この駒！ → 黄色のマス" : (game.isCPUThinking ? "CPUが考えています…" : "あなたの番")))
                if game.hintedMove == nil && !game.isFindingHint { Text("・ \(game.state.turnNumber)手目").foregroundStyle(.secondary) }
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.67, green: 0.22, blue: 0.20))
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(.white.opacity(0.88), in: Capsule())
        case .won(let winner, let reason):
            VStack(spacing: 1) {
                Text(winner == .human ? "あなたの勝ち！" : "CPUの勝ち")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Text(reason.description).font(.caption.bold())
            }.foregroundStyle(Color(red: 0.67, green: 0.22, blue: 0.20))
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            ActionButton(title: "戻す", icon: "arrow.uturn.backward", enabled: game.canUndo, action: game.undoTurn)
            ActionButton(title: game.isFindingHint ? "考え中" : "ヒント", icon: "lightbulb.fill",
                         enabled: game.canInteract && !game.isFindingHint, action: game.requestHint)
            ActionButton(title: "もう一度", icon: "arrow.counterclockwise", enabled: !game.isCPUThinking, action: game.restart)
                .accessibilityIdentifier("restartButton")
        }.frame(maxWidth: 390)
    }
}

private struct ActionButton: View {
    let title: String; let icon: String; let enabled: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(.white.opacity(enabled ? 0.92 : 0.5), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.82, green: 0.30, blue: 0.27).opacity(enabled ? 1 : 0.3), lineWidth: 1.5))
        }.buttonStyle(.plain).disabled(!enabled)
            .foregroundStyle(Color(red: 0.63, green: 0.20, blue: 0.19).opacity(enabled ? 1 : 0.45))
    }
}

private struct GameBoardView: View {
    @ObservedObject var game: GameViewModel
    private let red = Color(red: 0.82, green: 0.30, blue: 0.27)

    var body: some View {
        GeometryReader { proxy in
            let topLabel: CGFloat = 22
            let cell = min((proxy.size.width - 58) / CGFloat(Board.columns),
                           (proxy.size.height - topLabel) / CGFloat(Board.rows))
            let boardWidth = cell * CGFloat(Board.columns)
            let boardHeight = cell * CGFloat(Board.rows)
            let boardX = (proxy.size.width - boardWidth) / 2
            ZStack(alignment: .topLeading) {
                ForEach(0..<Board.columns, id: \.self) { column in
                    Text(String(UnicodeScalar(65 + column)!))
                        .font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(red)
                        .position(x: boardX + (CGFloat(column) + 0.5) * cell, y: topLabel / 2)
                }
                ForEach(0..<Board.rows, id: \.self) { row in
                    Text("\(row + 1)")
                        .font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(red)
                        .position(x: boardX - 18, y: topLabel + (CGFloat(row) + 0.5) * cell)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 0), count: Board.columns), spacing: 0) {
                    ForEach(0..<(Board.columns * Board.rows), id: \.self) { index in
                        let position = Position(column: index % Board.columns, row: index / Board.columns)
                        BoardSquare(position: position, piece: game.state.board[position],
                                    isSelected: game.selectedSource == .board(position),
                                    isLegalDestination: game.legalDestinations.contains(position),
                                    isHintDestination: game.hintedMove?.destination == position,
                                    isHintSource: game.hintedMove?.source == .board(position),
                                    isLastDestination: game.lastMove?.destination == position) {
                            game.tapSquare(position)
                        }.frame(height: cell)
                    }
                }
                .frame(width: boardWidth, height: boardHeight)
                .overlay(DashedGrid().stroke(red, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                .position(x: proxy.size.width / 2, y: topLabel + boardHeight / 2)
            }
        }
        .aspectRatio(0.66, contentMode: .fit)
        .allowsHitTesting(game.canInteract)
        .accessibilityIdentifier("gameBoard")
    }
}

private struct DashedGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for column in 0...Board.columns {
            let x = rect.width * CGFloat(column) / CGFloat(Board.columns)
            p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rect.height))
        }
        for row in 0...Board.rows {
            let y = rect.height * CGFloat(row) / CGFloat(Board.rows)
            p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return p
    }
}

private struct BoardSquare: View {
    let position: Position
    let piece: Piece?
    let isSelected: Bool
    let isLegalDestination: Bool
    let isHintDestination: Bool
    let isHintSource: Bool
    let isLastDestination: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear
                if isLastDestination { RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.28)).padding(3) }
                if isSelected { RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.42)).padding(5) }
                if isLegalDestination {
                    Circle().fill(piece == nil ? Color(red: 0.34, green: 0.64, blue: 0.24).opacity(0.62) : .red.opacity(0.42))
                        .frame(width: piece == nil ? 17 : 54)
                }
                if isHintDestination {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.yellow, lineWidth: 4).padding(5)
                        .shadow(color: .orange, radius: 4)
                }
                if let piece {
                    AnimalPieceCard(piece: piece)
                        .padding(7)
                        .transition(.asymmetric(insertion: .scale(scale: 0.35).combined(with: .opacity), removal: .scale(scale: 1.18).combined(with: .opacity)))
                }
                if isHintSource {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Color.yellow, lineWidth: 5).padding(4)
                        .shadow(color: .orange, radius: 6)
                    Text("この駒！")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.42, green: 0.20, blue: 0.02))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.yellow, in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 2)
                }
                if isLegalDestination, piece != nil {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Color(red: 0.92, green: 0.16, blue: 0.10), lineWidth: 4)
                        .padding(5)
                        .shadow(color: .yellow.opacity(0.9), radius: 5)
                    Text("取れる！")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color(red: 0.90, green: 0.16, blue: 0.10), in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 2)
                }
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier("square_\(position.column)_\(position.row)")
    }
}

private struct HandView: View {
    let player: Player
    let state: GameState
    let selectedSource: MoveSource?
    let action: (PieceType) -> Void
    private let types: [PieceType] = [.chick, .giraffe, .elephant]

    var body: some View {
        HStack(spacing: 7) {
            Text(player == .cpu ? "CPU" : "持ち駒")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.65, green: 0.20, blue: 0.18))
            let available = types.filter { state.handCount(for: player, type: $0) > 0 }
            if available.isEmpty {
                Text("なし").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(available, id: \.self) { type in
                    Button { action(type) } label: {
                        HStack(spacing: 5) {
                            ZStack(alignment: .bottomTrailing) {
                                AnimalPieceCard(piece: Piece(type: type, owner: player))
                                    .frame(width: 42, height: 42)
                                Text("×\(state.handCount(for: player, type: type))")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(.white).padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(Color(red: 0.66, green: 0.20, blue: 0.18), in: Capsule())
                                    .offset(x: 5, y: 4)
                        }
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(selectedSource == .hand(type) ? Color.yellow.opacity(0.75) : .white.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            if selectedSource == .hand(type) {
                                RoundedRectangle(cornerRadius: 8).stroke(Color.yellow, lineWidth: 3)
                                    .shadow(color: .orange.opacity(0.8), radius: 4)
                            }
                        }
                    }.buttonStyle(.plain).disabled(player == .cpu)
                    .accessibilityIdentifier("hand_\(player.rawValue)_\(type.rawValue)")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .frame(maxWidth: 390)
        .frame(height: 58)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.7), lineWidth: 1))
    }
}

private struct HomeView: View {
    let start: () -> Void
    let startOnline: () -> Void
    let showTutorial: () -> Void
    let showSettings: () -> Void
    let showStats: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 26)
            VStack(spacing: 2) {
                Text("いきものしょうぎ")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                Text("IKIMONO SHOGI")
                    .font(.system(size: 11, weight: .black, design: .rounded)).tracking(4)
            }
            .foregroundStyle(Color(red: 0.60, green: 0.18, blue: 0.16))

            ZStack {
                Circle().fill(.white.opacity(0.34)).frame(width: 270, height: 270)
                AnimalPieceCard(piece: Piece(type: .elephant, owner: .human))
                    .frame(width: 92, height: 92).rotationEffect(.degrees(-9)).offset(x: -86, y: 35)
                AnimalPieceCard(piece: Piece(type: .giraffe, owner: .human))
                    .frame(width: 92, height: 92).rotationEffect(.degrees(9)).offset(x: 86, y: 35)
                AnimalPieceCard(piece: Piece(type: .lion, owner: .human))
                    .frame(width: 118, height: 118).offset(y: -28)
                AnimalPieceCard(piece: Piece(type: .chick, owner: .human))
                    .frame(width: 75, height: 75).rotationEffect(.degrees(-4)).offset(y: 92)
            }
            .frame(height: 300)

            VStack(spacing: 14) {
                Button(action: start) {
                    Label("ひとりで遊ぶ", systemImage: "play.fill")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Color(red: 0.73, green: 0.23, blue: 0.19), in: RoundedRectangle(cornerRadius: 18))
                        .foregroundStyle(.white).shadow(color: .black.opacity(0.16), radius: 7, y: 4)
                }.buttonStyle(.plain)

                Button(action: startOnline) {
                    Label("オンラインで遊ぶ", systemImage: "person.2.fill")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(red: 0.73, green: 0.23, blue: 0.19), lineWidth: 2))
                        .foregroundStyle(Color(red: 0.65, green: 0.19, blue: 0.17))
                }.buttonStyle(.plain)

                HStack(spacing: 18) {
                    Button(action: showSettings) {
                        Label("設定", systemImage: "slider.horizontal.3")
                    }
                    Button(action: showTutorial) {
                        Label("遊び方", systemImage: "book.closed.fill")
                    }
                    Button(action: showStats) {
                        Label("記録", systemImage: "chart.bar.fill")
                    }
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .buttonStyle(.plain).foregroundStyle(Color(red: 0.60, green: 0.18, blue: 0.16))
            }
            .padding(18).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.85), lineWidth: 1.5))
            .frame(maxWidth: 360)
            .offset(y: 22)
            Spacer(minLength: 22)
        }
        .padding(.horizontal, 18)
    }
}

private struct InteractiveTutorialView: View {
    let finish: () -> Void
    @State private var step = 0
    @State private var board = GameEngine.initialState().board
    @State private var hasCapturedFish = false
    private let red = Color(red: 0.72, green: 0.22, blue: 0.18)

    private var lesson: Int {
        switch step { case 0...2: 0; case 3...5: 1; case 6...8: 2; default: 3 }
    }

    private var highlightedSource: Position? {
        switch step {
        case 0: Position(column: 0, row: 3)
        case 3: Position(column: 1, row: 3)
        case 9: Position(column: 1, row: 1)
        default: nil
        }
    }

    private var selectedPosition: Position? {
        switch step {
        case 1: Position(column: 0, row: 3)
        case 4: Position(column: 1, row: 3)
        case 10: Position(column: 1, row: 1)
        default: nil
        }
    }

    private var legalDestination: Position? {
        switch step {
        case 1: Position(column: 0, row: 2)
        case 4: Position(column: 1, row: 2)
        case 7: Position(column: 2, row: 2)
        case 10: Position(column: 1, row: 0)
        default: nil
        }
    }

    var body: some View {
        ZStack {
            MeadowBackground()
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("やってみよう！")
                            .font(.system(size: 27, weight: .black, design: .rounded))
                        Text("4つの れんしゅう")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(red)
                    Spacer()
                    Button("あとで", action: skip)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(red)
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .background(.white.opacity(0.86), in: Capsule())
                }

                tutorialMessage
                    .frame(maxWidth: 370)

                TutorialBoard(board: board, highlightedSource: highlightedSource,
                              selectedPosition: selectedPosition, legalDestination: legalDestination,
                              lastDestination: [2, 5, 8, 11].contains(step) ? completedDestination : nil) { position in
                    handleTap(position)
                }
                .frame(maxWidth: 320)

                if step == 6 || step == 7 {
                    Button { selectCapturedPiece() } label: {
                        HStack(spacing: 9) {
                            Text("とった こま")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            AnimalPieceCard(piece: Piece(type: .chick, owner: .human))
                                .frame(width: 48, height: 48)
                            Text(step == 6 ? "ここを おしてね" : "えらんだよ！")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(step == 7 ? Color.yellow.opacity(0.72) : .white.opacity(0.88), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(step == 6 ? Color.yellow : red, lineWidth: 3))
                    }
                    .buttonStyle(.plain).disabled(step != 6)
                } else if [2, 5, 8].contains(step) {
                    Button("つぎへ") { nextLesson() }
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .frame(maxWidth: 330).padding(.vertical, 11)
                        .background(red, in: RoundedRectangle(cornerRadius: 15)).foregroundStyle(.white)
                } else if step == 11 {
                    VStack(spacing: 10) {
                        Button(action: complete) {
                            Label("ホームへ", systemImage: "house.fill")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(red, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(.white)
                        }
                        Button("もういちど やる") { reset() }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(red)
                    }
                    .frame(maxWidth: 350)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    HStack(spacing: 7) {
                        ForEach(0..<4, id: \.self) { index in
                            Capsule().fill(index <= lesson ? red : .white.opacity(0.65))
                                .frame(width: index == lesson ? 28 : 10, height: 8)
                        }
                    }
                    .accessibilityLabel("れんしゅう \(lesson + 1) / 4")
                }
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 18).padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder private var tutorialMessage: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill([2, 5, 8, 11].contains(step) ? Color.green : Color(red: 0.97, green: 0.71, blue: 0.27))
                    .frame(width: 48, height: 48)
                Image(systemName: [2, 5, 8, 11].contains(step) ? "checkmark" : "hand.tap.fill")
                    .font(.system(size: 21, weight: .black)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(messageTitle)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                Text(messageDetail)
                    .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
    }

    private func handleTap(_ position: Position) {
        switch step {
        case 0 where position == Position(column: 0, row: 3): step = 1
        case 1 where position == Position(column: 0, row: 2):
            move(from: Position(column: 0, row: 3), to: position); step = 2
        case 3 where position == Position(column: 1, row: 3): step = 4
        case 4 where position == Position(column: 1, row: 2):
            move(from: Position(column: 1, row: 3), to: position)
            hasCapturedFish = true; step = 5
        case 7 where position == Position(column: 2, row: 2):
            board[position] = Piece(type: .chick, owner: .human)
            hasCapturedFish = false; step = 8
        case 9 where position == Position(column: 1, row: 1): step = 10
        case 10 where position == Position(column: 1, row: 0):
            board[Position(column: 1, row: 1)] = nil
            board[position] = Piece(type: .hen, owner: .human); step = 11
        default: return
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {}
    }

    private var completedDestination: Position? {
        switch step {
        case 2: Position(column: 0, row: 2)
        case 5: Position(column: 1, row: 2)
        case 8: Position(column: 2, row: 2)
        case 11: Position(column: 1, row: 0)
        default: nil
        }
    }

    private var messageTitle: String {
        switch step {
        case 0: "きいろの こざかなを おしてね"
        case 1: "ひかった マスを おしてね"
        case 2: "できた！ こまが うごいたよ"
        case 3: "きいろの カニを おしてね"
        case 4: "あいての こざかなを とってね"
        case 5: "とった こまは じぶんのもの！"
        case 6: "とった こざかなを おしてね"
        case 7: "ひかった マスに おいてね"
        case 8: "すきな マスに こまを おけたよ"
        case 9: "こざかなを おしてね"
        case 10: "いちばん うえへ すすめてね"
        default: "ぜんぶ できた！"
        }
    }

    private var messageDetail: String {
        switch step {
        case 0: "うごかしたい こまを えらぶよ"
        case 1: "こざかなは まえに 1マス すすむよ"
        case 2: "つぎは あいての こまを とってみよう"
        case 3: "カニは たてと よこに うごけるよ"
        case 4: "あかく ひかった こまを おそう"
        case 5: "とった こまは したに ならぶよ"
        case 6: "もちごまは あとで つかえるよ"
        case 7: "あいての いない マスに おけるよ"
        case 8: "さいごは へんしんを やってみよう"
        case 9: "いちばん おくまで あと 1マス！"
        case 10: "おくまで いくと つよくなるよ"
        default: "これで ほんばんも だいじょうぶ！"
        }
    }

    private func move(from source: Position, to destination: Position) {
        guard let piece = board[source] else { return }
        board[source] = nil; board[destination] = piece
    }

    private func selectCapturedPiece() {
        guard step == 6, hasCapturedFish else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { step = 7 }
    }

    private func nextLesson() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if step == 2 {
                var next = Board()
                next[Position(column: 1, row: 3)] = Piece(type: .giraffe, owner: .human)
                next[Position(column: 1, row: 2)] = Piece(type: .chick, owner: .cpu)
                board = next; step = 3
            } else if step == 5 {
                step = 6
            } else if step == 8 {
                var next = Board()
                next[Position(column: 1, row: 1)] = Piece(type: .chick, owner: .human)
                board = next; step = 9
            }
        }
    }

    private func reset() {
        withAnimation(.easeInOut(duration: 0.25)) {
            board = GameEngine.initialState().board
            hasCapturedFish = false
            step = 0
        }
    }

    private func skip() {
        AnalyticsService.tutorialSkipped(step: step)
        finish()
    }

    private func complete() {
        AnalyticsService.tutorialCompleted()
        finish()
    }
}

private struct TutorialBoard: View {
    let board: Board
    let highlightedSource: Position?
    let selectedPosition: Position?
    let legalDestination: Position?
    let lastDestination: Position?
    let tap: (Position) -> Void
    private let red = Color(red: 0.82, green: 0.30, blue: 0.27)

    var body: some View {
        GeometryReader { proxy in
            let topLabel: CGFloat = 22
            let cell = min((proxy.size.width - 58) / CGFloat(Board.columns),
                           (proxy.size.height - topLabel) / CGFloat(Board.rows))
            let boardWidth = cell * CGFloat(Board.columns)
            let boardHeight = cell * CGFloat(Board.rows)
            let boardX = (proxy.size.width - boardWidth) / 2
            ZStack(alignment: .topLeading) {
                ForEach(0..<Board.columns, id: \.self) { column in
                    Text(String(UnicodeScalar(65 + column)!))
                        .font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(red)
                        .position(x: boardX + (CGFloat(column) + 0.5) * cell, y: topLabel / 2)
                }
                ForEach(0..<Board.rows, id: \.self) { row in
                    Text("\(row + 1)")
                        .font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(red)
                        .position(x: boardX - 18, y: topLabel + (CGFloat(row) + 0.5) * cell)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 0), count: Board.columns), spacing: 0) {
                    ForEach(0..<(Board.columns * Board.rows), id: \.self) { index in
                        let position = Position(column: index % Board.columns, row: index / Board.columns)
                        BoardSquare(position: position, piece: board[position],
                                    isSelected: position == selectedPosition,
                                    isLegalDestination: position == legalDestination,
                                    isHintDestination: false,
                                    isHintSource: position == highlightedSource,
                                    isLastDestination: position == lastDestination) {
                            tap(position)
                        }
                        .frame(height: cell)
                    }
                }
                .frame(width: boardWidth, height: boardHeight)
                .overlay(DashedGrid().stroke(red, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                .position(x: proxy.size.width / 2, y: topLabel + boardHeight / 2)
            }
        }
        .aspectRatio(0.66, contentMode: .fit)
        .accessibilityIdentifier("tutorialBoard")
    }
}

private struct DifficultySheet: View {
    @ObservedObject var game: GameViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 1.0, green: 0.97, blue: 0.80), Color(red: 0.88, green: 0.95, blue: 0.66)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("CPUのつよさ").font(.title2.bold())
                Picker("CPUのつよさ", selection: $game.difficulty) {
                    ForEach(GameViewModel.Difficulty.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("つぎに CPUが うごくときから かわるよ。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Divider()
                Text("どちらから はじめる？").font(.title2.bold())
                VStack(spacing: 9) {
                    ForEach(GameViewModel.StartingSide.allCases) { side in
                        Button { game.startingSide = side } label: {
                            HStack(spacing: 12) {
                                Image(systemName: side.icon).font(.title3).frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(side.rawValue).font(.headline)
                                    Text(side.detail).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if game.startingSide == side { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(red: 0.72, green: 0.24, blue: 0.20)) }
                            }
                            .padding(12)
                            .background(game.startingSide == side ? Color(red: 1.0, green: 0.91, blue: 0.77) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain)
                    }
                }
                Divider()
                Text("おとと うごき").font(.title2.bold())
                VStack(spacing: 0) {
                    SettingToggle(icon: "speaker.wave.2.fill", title: "おと", isOn: $game.soundEnabled)
                    Divider().padding(.leading, 48)
                    SettingToggle(icon: "iphone.radiowaves.left.and.right", title: "ブルッと しらせる", isOn: $game.hapticsEnabled)
                    Divider().padding(.leading, 48)
                    SettingToggle(icon: "sparkles", title: "こまの うごき", isOn: $game.animationsEnabled)
                }
                .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(24)
            }
            }
                .navigationTitle("せってい").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("できた") { dismiss() } } }
                .tint(Color(red: 0.72, green: 0.24, blue: 0.20))
        }
        .presentationDetents([.large])
        .presentationCornerRadius(30)
        .presentationBackground(Color(red: 0.96, green: 0.96, blue: 0.77))
    }
}

private struct SettingToggle: View {
    let icon: String; let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color(red: 0.72, green: 0.24, blue: 0.20)).frame(width: 28)
            Text(title).font(.headline)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }.padding(13)
    }
}

private struct RulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 1.0, green: 0.97, blue: 0.80), Color(red: 0.86, green: 0.94, blue: 0.63)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ルール").font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(Color(red: 0.62, green: 0.20, blue: 0.17))
                    RuleRow(icon: "hand.tap.fill", title: "こまを うごかそう", text: "じぶんの こまを えらんで、ひかった マスを おしてね。")
                    RuleRow(icon: "crown.fill", title: "かちかた", text: "あいての きょうりゅうを とるか、じぶんの きょうりゅうを いちばん うえまで すすめよう。")
                    RuleRow(icon: "square.grid.3x3.fill", title: "とった こま", text: "とった こまは、あいての いない マスに おけるよ。")
                    RuleRow(icon: "arrow.up.circle.fill", title: "こざかなの へんしん", text: "こざかなが いちばん おくまで すすむと、つよい さかなに へんしんするよ。")
                    RuleRow(icon: "shippingbox.fill", title: "おくに おくとき", text: "もちごまの こざかなを いちばん おくに おいても、こざかなの ままだよ。")
                    RuleRow(icon: "arrow.triangle.2.circlepath", title: "おなじ ばめん", text: "おなじ ばめんを 4かいめに つくった ほうが まけだよ。")
                }.padding(20)
            }
            }
            .navigationTitle("ルール").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("とじる") { dismiss() } } }
                .tint(Color(red: 0.72, green: 0.24, blue: 0.20))
        }
        .presentationDetents([.large])
        .presentationCornerRadius(30)
        .presentationBackground(Color(red: 0.96, green: 0.96, blue: 0.77))
    }
}

private struct StatsSheet: View {
    @ObservedObject var game: GameViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.48, green: 0.79, blue: 0.91), Color(red: 0.85, green: 0.94, blue: 0.60)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                VStack(spacing: 18) {
                    Image(systemName: "trophy.fill").font(.system(size: 54)).foregroundStyle(.yellow)
                        .shadow(color: .orange.opacity(0.5), radius: 5, y: 3)
                    Text("これまでの きろく").font(.system(size: 25, weight: .black, design: .rounded)).foregroundStyle(Color(red: 0.58, green: 0.18, blue: 0.16))
                    HStack(spacing: 10) {
                        StatCard(value: game.gamesPlayed, label: "あそんだ")
                        StatCard(value: game.wins, label: "かった")
                        StatCard(value: game.losses, label: "まけた")
                    }
                    VStack(spacing: 10) {
                        StatRow(icon: "flame.fill", title: "いまの れんしょう", value: game.currentStreak)
                        StatRow(icon: "crown.fill", title: "いちばん ながい れんしょう", value: game.bestStreak)
                    }
                    Spacer()
                }.padding(24)
            }
            .navigationTitle("きろく").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("とじる") { dismiss() } } }
            .tint(Color(red: 0.72, green: 0.24, blue: 0.20))
        }
        .presentationDetents([.large]).presentationCornerRadius(30)
    }
}

private struct StatCard: View {
    let value: Int; let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.system(size: 31, weight: .black, design: .rounded))
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 18).background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct StatRow: View {
    let icon: String; let title: String; let value: Int
    var body: some View {
        HStack { Image(systemName: icon).foregroundStyle(.orange).frame(width: 28); Text(title).font(.headline); Spacer(); Text("\(value)").font(.title2.weight(.black)) }
            .padding(16).background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct RuleRow: View {
    let icon: String; let title: String; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color(red: 0.72, green: 0.25, blue: 0.20)).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(text).font(.subheadline).foregroundStyle(.secondary) }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.9), lineWidth: 1))
    }
}

private struct GameOverOverlay: View {
    let winner: Player; let reason: WinReason; let restart: () -> Void; let home: () -> Void
    @State private var animate = false
    var body: some View {
        ZStack {
            LinearGradient(colors: winner == .human ? [.yellow.opacity(0.68), .orange.opacity(0.55), .pink.opacity(0.46)] : [.indigo.opacity(0.70), .blue.opacity(0.56), .purple.opacity(0.54)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ForEach(0..<18, id: \.self) { index in
                Image(systemName: winner == .human ? (index.isMultiple(of: 2) ? "star.fill" : "sparkles") : (index.isMultiple(of: 2) ? "moon.stars.fill" : "sparkle"))
                    .font(.system(size: CGFloat(13 + (index % 4) * 5)))
                    .foregroundStyle(winner == .human ? Color.yellow : Color.white.opacity(0.82))
                    .position(x: CGFloat((index * 83) % 390) + 8, y: animate ? CGFloat((index * 127) % 760) : -40)
                    .rotationEffect(.degrees(animate ? Double(index * 83) : 0))
                    .animation(.easeOut(duration: 1.3 + Double(index % 5) * 0.18).delay(Double(index % 6) * 0.08), value: animate)
            }
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.24)).frame(width: 116, height: 116).scaleEffect(animate ? 1 : 0.3)
                    Image(systemName: winner == .human ? "trophy.fill" : "flag.checkered")
                        .font(.system(size: 54)).foregroundStyle(winner == .human ? .yellow : .orange)
                        .symbolEffect(.bounce, value: animate)
                }
                Text(winner == .human ? "やったね！" : "おしかったね")
                    .font(.system(size: 31, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text(winner == .human ? "あなたの かち！" : "CPUの かち")
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(reason.description).font(.subheadline).foregroundStyle(.secondary)
                Button(action: restart) {
                    Label("もういちど", systemImage: "arrow.counterclockwise")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(red: 0.75, green: 0.25, blue: 0.20), in: RoundedRectangle(cornerRadius: 15)).foregroundStyle(.white)
                }
                Button(action: home) {
                    Label("ホームへ", systemImage: "house.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 15))
                        .foregroundStyle(Color(red: 0.50, green: 0.18, blue: 0.18))
                }
            }
            .padding(28).frame(maxWidth: 310).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.8), lineWidth: 1))
            .shadow(radius: 18)
            .scaleEffect(animate ? 1 : 0.78).opacity(animate ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) { animate = true } }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

private struct MeadowBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color(red: 0.46, green: 0.78, blue: 0.91)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: proxy.size.height * 0.27))
                    p.addCurve(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.25), control1: CGPoint(x: proxy.size.width * 0.35, y: proxy.size.height * 0.32), control2: CGPoint(x: proxy.size.width * 0.72, y: proxy.size.height * 0.20))
                    p.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.72)); p.addLine(to: CGPoint(x: 0, y: proxy.size.height * 0.72)); p.closeSubpath()
                }.fill(Color(red: 1.0, green: 0.96, blue: 0.65))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: proxy.size.height * 0.67))
                    p.addCurve(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.65), control1: CGPoint(x: proxy.size.width * 0.2, y: proxy.size.height * 0.56), control2: CGPoint(x: proxy.size.width * 0.77, y: proxy.size.height * 0.78))
                    p.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height)); p.addLine(to: CGPoint(x: 0, y: proxy.size.height)); p.closeSubpath()
                }.fill(Color(red: 0.76, green: 0.88, blue: 0.39))
                Cloud().fill(.white).frame(width: 120, height: 70).offset(x: -proxy.size.width * 0.37, y: 18)
                Cloud().fill(.white).frame(width: 140, height: 78).offset(x: proxy.size.width * 0.35, y: 43)
            }.ignoresSafeArea()
        }
    }
}

private struct Cloud: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: rect.width * 0.05, y: rect.height * 0.35, width: rect.width * 0.42, height: rect.height * 0.55))
        p.addEllipse(in: CGRect(x: rect.width * 0.28, y: rect.height * 0.08, width: rect.width * 0.43, height: rect.height * 0.75))
        p.addEllipse(in: CGRect(x: rect.width * 0.55, y: rect.height * 0.3, width: rect.width * 0.4, height: rect.height * 0.56))
        p.addRect(CGRect(x: rect.width * 0.18, y: rect.height * 0.55, width: rect.width * 0.67, height: rect.height * 0.27))
        return p
    }
}

#Preview { ContentView() }
