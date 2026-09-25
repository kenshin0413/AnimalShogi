import SwiftUI
import AudioToolbox

struct OnlinePlayView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var online = OnlineGameService()
    @AppStorage("soundEnabled") private var soundEnabled = true
    @State private var name = ""
    @State private var icon = "Dinosaur"
    @State private var showingResign = false
    @State private var showingSafety = false
    @State private var showingReportReasons = false

    private let red = Color(red: 0.67, green: 0.16, blue: 0.13)
    private let actionRed = Color(red: 0.76, green: 0.18, blue: 0.15)

    var body: some View {
        ZStack {
            OnlineLandscapeBackground()
            VStack(spacing: 8) {
                header
                switch online.phase {
                case .profile: profileEditor
                case .ready: readyView
                case .searching: searchingView
                case .playing, .finished: gameView
                }
            }
            .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 8)
        }
        .task {
            await online.start()
            if let profile = online.profile { name = profile.name; icon = profile.icon }
        }
        .onChange(of: online.profile) { _, profile in
            guard let profile else { return }
            name = profile.name; icon = profile.icon
        }
        .onChange(of: online.phase) { oldPhase, newPhase in
            guard soundEnabled, oldPhase != newPhase else { return }
            if newPhase == .playing { AudioServicesPlaySystemSound(1025) }
            if newPhase == .finished {
                AudioServicesPlaySystemSound(online.winner == online.mySide ? 1025 : 1053)
            }
        }
        .alert("降参しますか？", isPresented: $showingResign) {
            Button("降参する", role: .destructive) { Task { await online.resign() } }
            Button("対戦を続ける", role: .cancel) {}
        } message: { Text("この対戦は負けになります") }
        .confirmationDialog("安心メニュー", isPresented: $showingSafety, titleVisibility: .visible) {
            Button("この名前を通報") { showingReportReasons = true }
            Button("この人をブロック", role: .destructive) { Task { await online.blockOpponent() } }
            Button("閉じる", role: .cancel) {}
        }
        .confirmationDialog("通報する理由", isPresented: $showingReportReasons, titleVisibility: .visible) {
            Button("嫌な名前") { Task { await online.reportOpponent(reason: "inappropriate_name") } }
            Button("個人情報") { Task { await online.reportOpponent(reason: "personal_information") } }
            Button("その他") { Task { await online.reportOpponent(reason: "other") } }
            Button("やめる", role: .cancel) {}
        }
        .alert("お知らせ", isPresented: Binding(
            get: { online.errorMessage != nil },
            set: { if !$0 { online.clearError() } }
        )) { Button("OK") {} } message: { Text(online.errorMessage ?? "") }
    }

    private var header: some View {
        HStack {
            Button { Task { await online.leave(); dismiss() } } label: {
                Image(systemName: "chevron.left").font(.headline.weight(.black))
                    .frame(width: 40, height: 40).background(.white.opacity(0.9), in: Circle())
            }
            Spacer()
            VStack(spacing: 0) {
                Text("いきものしょうぎ")
                    .font(.system(size: online.phase == .ready ? 27 : 21, weight: .black, design: .rounded))
                Text("オンライン対戦")
                    .font(.system(size: online.phase == .ready ? 13 : 11, weight: .black, design: .rounded)).tracking(1.8)
            }
            Spacer()
            if online.opponent != nil {
                Button { showingSafety = true } label: {
                    Image(systemName: "ellipsis").font(.headline.weight(.black))
                        .frame(width: 40, height: 40).background(.white.opacity(0.9), in: Circle())
                }
            } else { Color.clear.frame(width: 40, height: 40) }
        }
        .foregroundStyle(red).frame(maxWidth: 410)
    }

    private var profileEditor: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Text("プロフィールを作ろう")
                    .font(.system(size: 25, weight: .black, design: .rounded)).foregroundStyle(red).padding(.top, 8)
                Text("好きないきものを選んでね").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(OnlineProfile.icons, id: \.self) { item in
                        Button { icon = item } label: {
                            Image(item).resizable().scaledToFit().padding(8).frame(width: 64, height: 64)
                                .background(icon == item ? Color(red: 1, green: 0.91, blue: 0.42) : .white.opacity(0.9), in: RoundedRectangle(cornerRadius: 17))
                                .overlay(RoundedRectangle(cornerRadius: 17).stroke(icon == item ? actionRed : .white, lineWidth: icon == item ? 3 : 1.5))
                                .shadow(color: .black.opacity(icon == item ? 0.12 : 0.04), radius: 5, y: 3)
                        }.buttonStyle(.plain)
                    }
                }.padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 7) {
                    Text("対戦で使う名前").font(.subheadline.weight(.black)).foregroundStyle(red)
                    TextField("2〜10文字", text: $name)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(.system(size: 18, weight: .bold, design: .rounded)).padding(15)
                        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: 2))
                }
                Label("本名・電話番号・SNSのIDは書かないでね", systemImage: "lock.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                primaryButton("このプロフィールで始める", icon: "checkmark.circle.fill") {
                    Task { _ = await online.saveProfile(name: name, icon: icon) }
                }.padding(.top, 2)
            }
            .frame(maxWidth: 390).padding(.horizontal, 4).padding(.bottom, 16)
        }
    }

    private var readyView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                if let profile = online.profile {
                    ZStack {
                        Circle().fill(.white.opacity(0.30)).frame(width: 162, height: 162)
                        Image(profile.icon).resizable().scaledToFit().padding(17).frame(width: 138, height: 138)
                            .background(Color(red: 0.96, green: 0.58, blue: 0.58), in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.76), lineWidth: 3))
                            .shadow(color: .black.opacity(0.14), radius: 7, y: 4)
                    }
                    Text(profile.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(red)
                        .frame(maxWidth: 255).padding(.vertical, 8)
                        .background(.white.opacity(0.90), in: Capsule())

                    VStack(spacing: 3) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 25, weight: .black)).foregroundStyle(.green)
                            Text("\(profile.rank.rawValue)級")
                        }
                        .font(.system(size: 27, weight: .black, design: .rounded)).foregroundStyle(red)
                        Text("レート \(profile.rating)")
                            .font(.system(size: 19, weight: .black, design: .rounded)).foregroundStyle(red)
                    }

                    HStack(spacing: 20) {
                        scoreItem(label: "勝", value: profile.wins, color: .red)
                        Divider().frame(height: 36)
                        scoreItem(label: "負", value: profile.losses, color: .blue)
                    }
                    .padding(.horizontal, 28).padding(.vertical, 8)
                    .background(.white.opacity(0.88), in: Capsule())

                    HStack(spacing: 10) {
                        Rectangle().fill(red).frame(height: 1)
                        Text("対戦のルール").font(.system(size: 14, weight: .black, design: .rounded)).fixedSize()
                        Rectangle().fill(red).frame(height: 1)
                    }.foregroundStyle(red).padding(.horizontal, 35)

                    HStack(spacing: 10) {
                        largeRuleBadge("ランダムな\n相手と対戦", icon: "person.2.fill")
                        largeRuleBadge("先手・後手は\nランダム", icon: "die.face.5.fill")
                        largeRuleBadge("持ち時間\n7分ずつ", icon: "stopwatch.fill")
                    }
                }
                primaryButton("対戦相手をさがす", icon: "play.fill") { Task { await online.beginMatchmaking() } }
                Button { online.editProfile() } label: {
                    Label("プロフィールを変える", systemImage: "gearshape.fill")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .frame(maxWidth: 275).padding(.vertical, 10)
                        .background(.white.opacity(0.88), in: Capsule())
                }.foregroundStyle(red)
            }
            .frame(maxWidth: 390).padding(.top, 5).padding(.bottom, 14)
        }
    }

    private var searchingView: some View {
        VStack(spacing: 10) {
            Text("対戦相手を\nさがしています")
                .font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(red).multilineTextAlignment(.center)
            HStack(spacing: 6) {
                compactRule("ランダム対戦", icon: "die.face.5.fill")
                compactRule("持ち時間 7分", icon: "clock.fill")
                compactRule("先手・後手 ランダム", icon: "arrow.triangle.swap")
            }
            Spacer(minLength: 2)
            searchAvatar(icon: nil)
            AnimatedPawTrail(color: red).frame(height: 92)
            searchAvatar(icon: online.profile?.icon)
            Spacer(minLength: 2)
            Button { Task { await online.cancelMatchmaking() } } label: {
                Text("キャンセル").font(.system(size: 18, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(red, lineWidth: 2))
            }
            .foregroundStyle(red).frame(maxWidth: 330)
        }
        .frame(maxWidth: 390).padding(.top, 6).padding(.bottom, 8)
    }

    private var gameView: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            let boardHeight = max(280, min(compact ? 320 : 475, proxy.size.height - (compact ? 255 : 230)))
            ZStack {
                VStack(spacing: compact ? 3 : 5) {
                    playerBar(profile: online.opponent, time: online.opponentTime, isMe: false, compact: compact)
                    onlineHand(player: online.mySide.opponent, enabled: false, compact: compact)
                    HStack(spacing: 6) {
                        Circle().fill(online.canInteract ? Color.green : Color.orange).frame(width: 9, height: 9)
                        Text(online.message)
                        Spacer()
                        Text("1手 \(Int(ceil(online.turnRemaining)))秒")
                    }
                    .font(.system(size: compact ? 11 : 12, weight: .black, design: .rounded)).padding(.horizontal, 11)
                    .frame(height: compact ? 25 : 29).background(.white.opacity(0.86), in: Capsule())
                    OnlineBoardView(online: online)
                        .frame(width: boardHeight * 0.66, height: boardHeight).frame(maxWidth: .infinity)
                    onlineHand(player: online.mySide, enabled: true, compact: compact)
                    playerBar(profile: online.profile, time: online.myTime, isMe: true, compact: compact)
                    if online.phase == .playing {
                        HStack {
                            Text(
                                online.matchStartsAt.map { Date() < $0 } == true
                                    ? "対局開始を待っています"
                                    : (online.state.currentPlayer == online.mySide ? "あなたの手番です" : "相手の手番です")
                            )
                                .font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white)
                                .padding(.horizontal, 16).padding(.vertical, 7).background(actionRed, in: Capsule())
                            Spacer()
                            Button { showingResign = true } label: {
                                Label("降参", systemImage: "flag.fill").font(.subheadline.weight(.black))
                                    .padding(.horizontal, 13).padding(.vertical, 7).background(.white.opacity(0.9), in: Capsule())
                            }.foregroundStyle(red)
                        }
                    }
                }.frame(maxWidth: 400, maxHeight: .infinity)
                if online.phase == .finished {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    resultPanel.padding(.horizontal, 18).transition(.scale.combined(with: .opacity))
                }
                if online.phase == .playing, let startsAt = online.matchStartsAt {
                    MatchIntroOverlay(
                        opponent: online.opponent,
                        me: online.profile,
                        startsAt: startsAt,
                        isMeFirst: online.state.currentPlayer == online.mySide,
                        accent: red
                    )
                }
            }
        }
    }

    private func playerBar(profile: OnlineProfile?, time: TimeInterval, isMe: Bool, compact: Bool) -> some View {
        HStack(spacing: 9) {
            if let profile {
                Image(profile.icon).resizable().scaledToFit().padding(4)
                    .frame(width: compact ? 34 : 40, height: compact ? 34 : 40)
                    .background(Color(red: 0.46, green: 0.79, blue: 0.91), in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(isMe ? "あなた" : (profile?.name ?? "相手を読み込み中"))
                    .font(.system(size: compact ? 14 : 16, weight: .black, design: .rounded)).lineLimit(1)
                Text("\(profile?.rank.rawValue ?? "ひよこ")級")
                    .font(.caption2.weight(.black)).foregroundStyle(.secondary)
            }
            Spacer()
            Label(clock(time), systemImage: "clock.fill")
                .font(.system(size: compact ? 18 : 22, weight: .black, design: .monospaced))
                .foregroundStyle(time < 30 ? .red : red)
        }
        .padding(.horizontal, 11).frame(height: compact ? 43 : 51)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white, lineWidth: 1.5))
    }

    private func onlineHand(player: Player, enabled: Bool, compact: Bool) -> some View {
        let handTypes: [PieceType] = [.chick, .giraffe, .elephant]
        return HStack(spacing: 6) {
            Text("持ち駒").font(.caption2.weight(.black)).foregroundStyle(red).frame(width: 42, alignment: .leading)
            ForEach(Array(handTypes.enumerated()), id: \.offset) { item in
                let type = item.element
                let count = online.state.handCount(for: player, type: type)
                Button { online.selectHandPiece(type) } label: {
                    ZStack(alignment: .bottomTrailing) {
                        if count > 0 {
                            AnimalPieceCard(piece: Piece(type: type, owner: enabled ? .human : .cpu))
                                .frame(width: compact ? 30 : 35, height: compact ? 30 : 35)
                            if count > 1 {
                                Text("×\(count)").font(.system(size: 9, weight: .black)).padding(2).background(.white, in: Capsule())
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 6).stroke(red.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3]))
                                .frame(width: compact ? 30 : 35, height: compact ? 30 : 35)
                        }
                    }
                }.buttonStyle(.plain).disabled(!enabled || count == 0)
            }
            Spacer()
        }
        .padding(.horizontal, 9).frame(height: compact ? 34 : 40)
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 11))
    }

    private var resultPanel: some View {
        VStack(spacing: 12) {
            Image(systemName: online.winner == online.mySide ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 42, weight: .black)).foregroundStyle(online.winner == online.mySide ? .yellow : red)
            Text(online.winner == online.mySide ? "勝ち！" : "対戦終了")
                .font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(red)
            Text(resultMessage).font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
            if let change = online.ratingChange {
                HStack(spacing: 8) {
                    Text("レート")
                    Text(change >= 0 ? "+\(change)" : "\(change)")
                        .foregroundStyle(change >= 0 ? Color.green : Color.red)
                }
                .font(.system(size: 20, weight: .black, design: .rounded))
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(Color.gray.opacity(0.10), in: Capsule())
            }
            Button("オンライン対戦へ戻る") { Task { await online.leave() } }
                .font(.headline.weight(.black)).frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(actionRed, in: RoundedRectangle(cornerRadius: 15)).foregroundStyle(.white)
        }
        .padding(22).background(.white, in: RoundedRectangle(cornerRadius: 25))
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8).frame(maxWidth: 340)
    }

    private var resultMessage: String {
        if online.endReason == .resignation {
            return online.didResign ? "降参しました" : "相手が降参しました"
        }
        return online.endReason?.label ?? "対戦終了"
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 19, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(actionRed, in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(.white)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white, lineWidth: 2))
                .shadow(color: red.opacity(0.2), radius: 7, y: 4)
        }.buttonStyle(.plain)
    }

    private func ruleBadge(_ text: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3)
            Text(text).font(.system(size: 11, weight: .black, design: .rounded)).multilineTextAlignment(.center).lineLimit(2)
        }
        .foregroundStyle(red).frame(maxWidth: .infinity, minHeight: 66)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 18))
    }

    private func largeRuleBadge(_ text: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .black))
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.88), in: Circle())
            Text(text)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .multilineTextAlignment(.center).lineLimit(2)
        }
        .foregroundStyle(red).frame(maxWidth: .infinity)
    }

    private func scoreItem(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 7) {
            Text(label).font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(color, in: Circle())
            Text("\(value)").font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(red)
        }
    }

    private func compactRule(_ text: String, icon: String) -> some View {
        VStack(spacing: 3) { Image(systemName: icon); Text(text).lineLimit(2).minimumScaleFactor(0.75) }
            .font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(red)
            .frame(maxWidth: .infinity, minHeight: 50).background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 15))
    }

    private func searchAvatar(icon: String?) -> some View {
        ZStack {
            Circle().fill(.white.opacity(0.44)).frame(width: 116, height: 116)
            RoundedRectangle(cornerRadius: 20)
                .fill(icon == nil ? Color(red: 0.75, green: 0.66, blue: 0.78) : Color(red: 0.96, green: 0.58, blue: 0.58))
                .frame(width: 92, height: 92).overlay(RoundedRectangle(cornerRadius: 20).stroke(red.opacity(0.8), lineWidth: 3))
            if let icon { Image(icon).resizable().scaledToFit().padding(12).frame(width: 92, height: 92) }
            else { Image(systemName: "questionmark").font(.system(size: 42, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.9)) }
        }
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(ceil(seconds)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct MatchIntroOverlay: View {
    let opponent: OnlineProfile?
    let me: OnlineProfile?
    let startsAt: Date
    let isMeFirst: Bool
    let accent: Color
    @AppStorage("soundEnabled") private var soundEnabled = true
    @State private var lastCountdown = ""

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            let remaining = startsAt.timeIntervalSince(timeline.date)
            if remaining > 0 {
                ZStack {
                    Color.black.opacity(0.42).ignoresSafeArea()
                    if remaining > 3 {
                        VStack(spacing: 12) {
                            Text("対戦相手が見つかりました！")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                            matchupCard(profile: opponent, label: "対戦相手", order: isMeFirst ? "後手" : "先手")
                            Text("VS")
                                .font(.system(size: 35, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: accent, radius: 5)
                            matchupCard(profile: me, label: "あなた", order: isMeFirst ? "先手" : "後手")
                        }
                        .padding(.horizontal, 22)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        let countdown = remaining > 2 ? "3" : remaining > 1 ? "2" : "1"
                        VStack(spacing: 13) {
                            Text(countdown)
                                .font(.system(size: 92, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: accent, radius: 8)
                                .id(countdown)
                                .transition(.scale.combined(with: .opacity))
                            Text("まもなく対局開始")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .animation(.spring(response: 0.25, dampingFraction: 0.72), value: countdown)
                        .onAppear { playCountdownIfNeeded(countdown) }
                        .onChange(of: countdown) { _, value in playCountdownIfNeeded(value) }
                    }
                }
                .allowsHitTesting(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("対戦相手が見つかりました。対局開始までカウントダウンします")
    }

    private func playCountdownIfNeeded(_ value: String) {
        guard soundEnabled, value != lastCountdown else { return }
        lastCountdown = value
        AudioServicesPlaySystemSound(1104)
    }

    private func matchupCard(profile: OnlineProfile?, label: String, order: String) -> some View {
        HStack(spacing: 13) {
            if let profile {
                Image(profile.icon).resizable().scaledToFit().padding(6)
                    .frame(width: 64, height: 64)
                    .background(Color(red: 0.47, green: 0.79, blue: 0.91), in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            } else {
                ProgressView().tint(accent).frame(width: 64, height: 64)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption.weight(.black)).foregroundStyle(.secondary)
                Text(profile?.name ?? "読み込み中")
                    .font(.system(size: 20, weight: .black, design: .rounded)).lineLimit(1)
                Text("\(profile?.rank.rawValue ?? "ひよこ")級  ・  レート \(profile?.rating ?? 1000)")
                    .font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.72)
            }
            Spacer(minLength: 5)
            Text(order)
                .font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 7).background(accent, in: Capsule())
        }
        .padding(13)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .frame(maxWidth: 355)
    }
}

private struct AnimatedPawTrail: View {
    let color: Color
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.22)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate * 3) % 5
            VStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: "pawprint.fill").font(.system(size: 15 + CGFloat(index))).foregroundStyle(color)
                        .opacity(index == step ? 1 : (index < step ? 0.46 : 0.16))
                        .offset(x: index.isMultiple(of: 2) ? -8 : 8).scaleEffect(index == step ? 1.18 : 1)
                        .animation(.easeInOut(duration: 0.2), value: step)
                }
            }
        }.accessibilityLabel("対戦相手を検索中")
    }
}

private struct OnlineLandscapeBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.46, green: 0.78, blue: 0.90)
                OnlineHillShape(waveHeight: 0.08).fill(Color(red: 1.0, green: 0.95, blue: 0.62))
                    .frame(height: proxy.size.height * 0.73).frame(maxHeight: .infinity, alignment: .bottom)
                OnlineHillShape(waveHeight: 0.13).fill(Color(red: 0.72, green: 0.88, blue: 0.34))
                    .frame(height: proxy.size.height * 0.29).frame(maxHeight: .infinity, alignment: .bottom)
                HStack {
                    CloudShape().fill(.white.opacity(0.92)).frame(width: 105, height: 52)
                    Spacer()
                    CloudShape().fill(.white.opacity(0.92)).frame(width: 120, height: 58)
                }.offset(y: -proxy.size.height * 0.39)
            }
        }.ignoresSafeArea()
    }
}

private struct OnlineHillShape: Shape {
    let waveHeight: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * waveHeight))
        path.addCurve(to: CGPoint(x: rect.width, y: 0),
                      control1: CGPoint(x: rect.width * 0.30, y: rect.height * waveHeight * 2.2),
                      control2: CGPoint(x: rect.width * 0.70, y: -rect.height * waveHeight))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height)); path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath(); return path
    }
}

private struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 0, y: rect.height * 0.37, width: rect.width * 0.43, height: rect.height * 0.53))
        path.addEllipse(in: CGRect(x: rect.width * 0.22, y: 0, width: rect.width * 0.46, height: rect.height * 0.78))
        path.addEllipse(in: CGRect(x: rect.width * 0.54, y: rect.height * 0.27, width: rect.width * 0.46, height: rect.height * 0.60))
        path.addRect(CGRect(x: rect.width * 0.13, y: rect.height * 0.50, width: rect.width * 0.75, height: rect.height * 0.35))
        return path
    }
}

private struct OnlineBoardView: View {
    @ObservedObject var online: OnlineGameService
    private let red = Color(red: 0.82, green: 0.30, blue: 0.27)
    var body: some View {
        GeometryReader { proxy in
            let leftInset: CGFloat = 24, topInset: CGFloat = 20
            let cell = min((proxy.size.width - leftInset) / CGFloat(Board.columns), (proxy.size.height - topInset) / CGFloat(Board.rows))
            let width = cell * CGFloat(Board.columns), height = cell * CGFloat(Board.rows)
            // 行番号を含む領域ではなく、実際の盤面を画面の中心線に合わせる。
            let originX = (proxy.size.width - width) / 2
            let originY = topInset + (proxy.size.height - topInset - height) / 2
            ZStack(alignment: .topLeading) {
                ForEach(0..<Board.columns, id: \.self) { column in
                    Text(String(UnicodeScalar(65 + column)!)).font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(red)
                        .frame(width: cell).position(x: originX + cell * (CGFloat(column) + 0.5), y: 8)
                }
                ForEach(0..<Board.rows, id: \.self) { row in
                    Text("\(row + 1)").font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(red)
                        .frame(width: leftInset).position(x: leftInset / 2, y: originY + cell * (CGFloat(row) + 0.5))
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 0), count: Board.columns), spacing: 0) {
                    ForEach(0..<(Board.columns * Board.rows), id: \.self) { index in
                        let shown = Position(column: index % Board.columns, row: index / Board.columns)
                        let canonical = online.canonical(shown), piece = online.state.board[canonical]
                        Button { online.tapSquare(shown) } label: {
                            ZStack {
                                Color.clear
                                if online.selectedSource == .board(canonical) { RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.5)).padding(3) }
                                if online.legalDestinations.contains(canonical) {
                                    Circle().fill(piece == nil ? Color.green.opacity(0.68) : Color.red.opacity(0.42))
                                        .frame(width: piece == nil ? 15 : cell * 0.72)
                                }
                                if let piece {
                                    AnimalPieceCard(piece: Piece(type: piece.type, owner: piece.owner == online.mySide ? .human : .cpu)).padding(cell * 0.08)
                                }
                                if online.legalDestinations.contains(canonical), piece != nil {
                                    RoundedRectangle(cornerRadius: 9).stroke(.red, lineWidth: 3).padding(4)
                                }
                            }.frame(width: cell, height: cell).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
                .frame(width: width, height: height)
                .overlay(OnlineGrid().stroke(red, style: StrokeStyle(lineWidth: 1.4, dash: [4, 3])))
                .position(x: originX + width / 2, y: originY + height / 2)
            }
        }
    }
}

private struct OnlineGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for column in 0...Board.columns {
            let x = rect.width * CGFloat(column) / CGFloat(Board.columns)
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        for row in 0...Board.rows {
            let y = rect.height * CGFloat(row) / CGFloat(Board.rows)
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}
