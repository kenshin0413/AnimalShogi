import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class OnlineGameService: ObservableObject {
    static let totalTime: TimeInterval = 7 * 60
    static let turnTime: TimeInterval = 60

    @Published private(set) var phase: OnlineMatchPhase = .profile
    @Published private(set) var profile: OnlineProfile?
    @Published private(set) var opponent: OnlineProfile?
    @Published private(set) var state = GameEngine.initialState()
    @Published private(set) var mySide: Player = .human
    @Published private(set) var selectedSource: MoveSource?
    @Published private(set) var lastMove: Move?
    @Published private(set) var myTime = totalTime
    @Published private(set) var opponentTime = totalTime
    @Published private(set) var turnRemaining = turnTime
    @Published private(set) var matchStartsAt: Date?
    @Published private(set) var message = "準備中…"
    @Published private(set) var errorMessage: String?
    @Published private(set) var winner: Player?
    @Published private(set) var endReason: OnlineMatchEnd?
    @Published private(set) var didResign = false
    @Published private(set) var ratingChange: Int?

    private let db: Firestore
    private var uid: String?
    private var matchID: String?
    private var queueListener: ListenerRegistration?
    private var queueHeartbeatTask: Task<Void, Never>?
    private var matchmakingTask: Task<Void, Never>?
    private var matchmakingTimeoutTask: Task<Void, Never>?
    private var matchListener: ListenerRegistration?
    private var timerTask: Task<Void, Never>?
    private var turnStartedAt = Date()
    private var baseMyTime = totalTime
    private var baseOpponentTime = totalTime
    private var recordedResult = false
#if DEBUG
    private var lastAutomatedMoveNumber = -1
#endif

    init() {
        db = Firestore.firestore()
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-useFirebaseEmulators") {
            let host = ProcessInfo.processInfo.environment["FIREBASE_EMULATOR_HOST"] ?? "127.0.0.1"
            Auth.auth().useEmulator(withHost: host, port: 9099)
            db.useEmulator(withHost: host, port: 8080)
            let settings = db.settings
            settings.isSSLEnabled = false
            db.settings = settings
        }
#endif
    }

    var canInteract: Bool {
        phase == .playing
            && state.result == .playing
            && state.currentPlayer == mySide
            && (matchStartsAt.map { Date() >= $0 } ?? true)
    }
    var legalDestinations: Set<Position> {
        guard let selectedSource else { return [] }
        return GameEngine.legalDestinations(for: selectedSource, in: state)
    }

    func clearError() {
        errorMessage = nil
    }

    func start() async {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-onlinePreviewProfile") || arguments.contains("-onlinePreviewReady") || arguments.contains("-onlinePreviewSearching")
            || arguments.contains("-onlinePreviewGame") || arguments.contains("-onlinePreviewIntro")
            || arguments.contains("-onlinePreviewWin") || arguments.contains("-onlinePreviewLoss") {
            profile = OnlineProfile(uid: "preview-me", name: "あなたのばん", icon: "Dinosaur", rating: 1120,
                                    wins: 12, losses: 8, draws: 2, currentStreak: 2, bestStreak: 5)
            if arguments.contains("-onlinePreviewProfile") {
                profile = nil
                phase = .profile
            } else if arguments.contains("-onlinePreviewSearching") {
                phase = .searching
            } else if arguments.contains("-onlinePreviewGame") || arguments.contains("-onlinePreviewIntro")
                        || arguments.contains("-onlinePreviewWin") || arguments.contains("-onlinePreviewLoss") {
                opponent = OnlineProfile(uid: "preview-rival", name: "もりのくま", icon: "Bear", rating: 1090,
                                         wins: 9, losses: 7, draws: 1, currentStreak: 1, bestStreak: 4)
                mySide = .human
                myTime = 378
                opponentTime = 402
                turnRemaining = 46
                message = "あなたの番"
                matchStartsAt = arguments.contains("-onlinePreviewIntro") ? Date().addingTimeInterval(6) : Date().addingTimeInterval(-1)
                if arguments.contains("-onlinePreviewWin") || arguments.contains("-onlinePreviewLoss") {
                    let didWin = arguments.contains("-onlinePreviewWin")
                    winner = didWin ? mySide : mySide.opponent
                    endReason = .game
                    ratingChange = didWin ? 16 : -16
                    phase = .finished
                } else {
                    phase = .playing
                }
            } else {
                phase = .ready
            }
            return
        }
#endif
        do {
            let user = try await signedInUser()
            uid = user.uid
            try await loadProfile(uid: user.uid)
            if profile != nil { await resumeActiveMatch(uid: user.uid) }
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-onlineTestA") || arguments.contains("-onlineTestB") {
                if profile == nil {
                    let isA = arguments.contains("-onlineTestA")
                    _ = await saveProfile(name: isA ? "テストA" : "テストB", icon: isA ? "Dinosaur" : "Crab")
                }
                if phase == .ready { await beginMatchmaking() }
            }
#endif
        } catch {
            errorMessage = "オンラインに つながらなかったよ"
        }
    }

    func saveProfile(name: String, icon: String) async -> Bool {
        if let validation = NameValidator.error(for: name) {
            errorMessage = validation
            return false
        }
        guard let uid else { return false }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedIcon = OnlineProfile.icons.contains(icon) ? icon : "Dinosaur"
        do {
            try await db.collection("profiles").document(uid).setData([
                "name": cleanName,
                "nameKey": NameValidator.normalizedForCheck(cleanName),
                "icon": selectedIcon,
                "rating": profile?.rating ?? 1000,
                "wins": profile?.wins ?? 0,
                "losses": profile?.losses ?? 0,
                "draws": profile?.draws ?? 0,
                "currentStreak": profile?.currentStreak ?? 0,
                "bestStreak": profile?.bestStreak ?? 0,
                "nameDisabled": false,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            try await loadProfile(uid: uid)
            return true
        } catch {
            errorMessage = "名前を 保存できなかったよ"
            return false
        }
    }

    func editProfile() {
        guard phase == .ready else { return }
        phase = .profile
    }

    func beginMatchmaking() async {
        guard uid != nil, let profile else { return }
        phase = .searching
        message = "対戦相手を 探しています…"
        errorMessage = nil
        scheduleMatchmakingTimeout()
        do {
            let blocked = try await blockedUIDs()
            if let candidate = try await availableCandidate(blocked: blocked) {
                try await claim(candidate: candidate, profile: profile)
            } else {
                try await waitInQueue(blocked: Array(blocked), profile: profile)
            }
        } catch {
            phase = .ready
            errorMessage = "マッチングを 始められなかったよ"
        }
    }

    func cancelMatchmaking() async {
        queueListener?.remove()
        queueListener = nil
        queueHeartbeatTask?.cancel(); queueHeartbeatTask = nil
        matchmakingTask?.cancel(); matchmakingTask = nil
        matchmakingTimeoutTask?.cancel(); matchmakingTimeoutTask = nil
        if let uid { try? await db.collection("matchQueue").document(uid).delete() }
        phase = .ready
        message = "オンライン対戦"
    }

    func tapSquare(_ displayed: Position) {
        guard canInteract else { return }
        let position = canonical(displayed)
        if let selectedSource, legalDestinations.contains(position) {
            Task { await send(move: Move(source: selectedSource, destination: position)) }
        } else if let piece = state.board[position], piece.owner == mySide {
            selectedSource = .board(position)
        } else {
            selectedSource = nil
        }
    }

    func selectHandPiece(_ type: PieceType) {
        guard canInteract, state.handCount(for: mySide, type: type) > 0 else { return }
        let source = MoveSource.hand(type)
        selectedSource = selectedSource == source ? nil : source
    }

    func displayed(_ canonical: Position) -> Position {
        mySide == .human ? canonical : Position(column: Board.columns - 1 - canonical.column, row: Board.rows - 1 - canonical.row)
    }

    func canonical(_ displayed: Position) -> Position { self.displayed(displayed) }

    func resign() async {
        guard phase == .playing, let matchID, let uid else { return }
        try? await db.collection("matches").document(matchID).updateData([
            "status": "finished", "winnerUID": opponentUID ?? "", "endReason": OnlineMatchEnd.resignation.rawValue,
            "resignedBy": uid, "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func reportOpponent(reason: String) async {
        guard let uid, let opponent else { return }
        _ = try? await db.collection("reports").addDocument(data: [
            "reporterUID": uid, "reportedUID": opponent.uid, "reportedName": opponent.name,
            "reason": reason, "matchID": matchID ?? "", "createdAt": FieldValue.serverTimestamp(), "status": "open"
        ])
    }

    func blockOpponent() async {
        guard let uid, let opponent else { return }
        try? await db.collection("profiles").document(uid).collection("blocks").document(opponent.uid).setData([
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func leave() async {
        if phase == .searching { await cancelMatchmaking() }
        matchListener?.remove(); matchListener = nil
        queueHeartbeatTask?.cancel(); queueHeartbeatTask = nil
        matchmakingTask?.cancel(); matchmakingTask = nil
        matchmakingTimeoutTask?.cancel(); matchmakingTimeoutTask = nil
        timerTask?.cancel(); timerTask = nil
        phase = profile == nil ? .profile : .ready
        opponent = nil; matchID = nil; matchStartsAt = nil
        selectedSource = nil; winner = nil; endReason = nil; didResign = false; ratingChange = nil
        recordedResult = false
    }

    private var opponentUID: String? {
        guard let uid, let opponent, opponent.uid != uid else { return nil }
        return opponent.uid
    }

    private func signedInUser() async throws -> User {
        if let current = Auth.auth().currentUser { return current }
        return try await Auth.auth().signInAnonymously().user
    }

    private func loadProfile(uid: String) async throws {
        let document = try await db.collection("profiles").document(uid).getDocument()
        guard document.exists, let data = document.data(), data["nameDisabled"] as? Bool != true else {
            profile = nil; phase = .profile; return
        }
        profile = profile(from: data, uid: uid)
        phase = .ready
        message = "オンライン対戦"
    }

    private func profile(from data: [String: Any], uid: String) -> OnlineProfile {
        OnlineProfile(uid: uid, name: data["name"] as? String ?? "プレイヤー", icon: data["icon"] as? String ?? "Dinosaur",
                      rating: data["rating"] as? Int ?? 1000, wins: data["wins"] as? Int ?? 0,
                      losses: data["losses"] as? Int ?? 0, draws: data["draws"] as? Int ?? 0,
                      currentStreak: data["currentStreak"] as? Int ?? 0, bestStreak: data["bestStreak"] as? Int ?? 0)
    }

    private func blockedUIDs() async throws -> Set<String> {
        guard let uid else { return [] }
        let snapshot = try await db.collection("profiles").document(uid).collection("blocks").getDocuments()
        return Set(snapshot.documents.map(\.documentID))
    }

    private func resumeActiveMatch(uid: String) async {
        guard let snapshot = try? await db.collection("matches")
            .whereField("players", arrayContains: uid)
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .getDocuments(), let match = snapshot.documents.first else { return }
        await observeMatch(match.documentID)
    }

    private func waitInQueue(blocked: [String], profile: OnlineProfile) async throws {
        guard let uid else { return }
        let reference = db.collection("matchQueue").document(uid)
        try await reference.setData([
            "uid": uid, "rating": profile.rating, "status": "waiting", "blocked": blocked,
            "createdAt": FieldValue.serverTimestamp(), "updatedAt": FieldValue.serverTimestamp()
        ])
        queueListener = reference.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let data = snapshot?.data(), let matchID = data["matchID"] as? String else { return }
            Task { @MainActor in await self.observeMatch(matchID) }
        }
        queueHeartbeatTask?.cancel()
        queueHeartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                try? await reference.updateData(["updatedAt": FieldValue.serverTimestamp()])
            }
        }
        matchmakingTask?.cancel()
        matchmakingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled, self.phase == .searching, let profile = self.profile else { return }
                if let candidate = try? await self.availableCandidate(blocked: Set(blocked)) {
                    do { try await self.claim(candidate: candidate, profile: profile); return }
                    catch { continue }
                }
            }
        }
    }

    private func scheduleMatchmakingTimeout() {
        matchmakingTimeoutTask?.cancel()
        matchmakingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(180))
            guard let self, !Task.isCancelled, self.phase == .searching else { return }
            await self.cancelMatchmaking()
        }
    }

    private func availableCandidate(blocked: Set<String>) async throws -> QueryDocumentSnapshot? {
        guard let uid, let rating = profile?.rating else { return nil }
        let cutoff = Timestamp(date: Date().addingTimeInterval(-15))
        let snapshot = try await db.collection("matchQueue")
            .whereField("status", isEqualTo: "waiting")
            .whereField("updatedAt", isGreaterThan: cutoff)
            .order(by: "updatedAt")
            .limit(to: 12)
            .getDocuments()
        return snapshot.documents
            .filter { doc in
                let other = doc.documentID
                let theirBlocked = doc.data()["blocked"] as? [String] ?? []
                return other != uid && !blocked.contains(other) && !theirBlocked.contains(uid)
            }
            .min { left, right in
                abs((left.data()["rating"] as? Int ?? 1000) - rating) < abs((right.data()["rating"] as? Int ?? 1000) - rating)
            }
    }

    private func claim(candidate: QueryDocumentSnapshot, profile: OnlineProfile) async throws {
        guard let uid else { return }
        let opponentUID = candidate.documentID
        let match = db.collection("matches").document()
        let firstUID = Bool.random() ? uid : opponentUID
        let initial = GameEngine.initialState(firstPlayer: firstUID == uid ? .human : .cpu)
        let encoded = try JSONEncoder().encode(initial).base64EncodedString()
        // 対戦相手の紹介を3秒、その後の3・2・1を各1秒表示する。
        let startsAt = Date().addingTimeInterval(6)
        let batch = db.batch()
        batch.setData([
            "players": [uid, opponentUID], "player1UID": uid, "player2UID": opponentUID,
            "firstUID": firstUID, "currentUID": firstUID, "stateData": encoded, "moveNumber": 0,
            "player1Millis": Int(Self.totalTime * 1000), "player2Millis": Int(Self.totalTime * 1000),
            "status": "active", "createdAt": FieldValue.serverTimestamp(), "startsAt": Timestamp(date: startsAt),
            "turnStartedAt": Timestamp(date: startsAt),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: match)
        batch.updateData(["status": "matched", "matchID": match.documentID, "updatedAt": FieldValue.serverTimestamp()], forDocument: candidate.reference)
        batch.deleteDocument(db.collection("matchQueue").document(uid))
        try await batch.commit()
        await observeMatch(match.documentID)
    }

    private func observeMatch(_ id: String) async {
        queueListener?.remove(); queueListener = nil
        queueHeartbeatTask?.cancel(); queueHeartbeatTask = nil
        matchmakingTask?.cancel(); matchmakingTask = nil
        matchmakingTimeoutTask?.cancel(); matchmakingTimeoutTask = nil
        if let uid { try? await db.collection("matchQueue").document(uid).delete() }
        matchID = id
        recordedResult = false
        ratingChange = nil
        matchListener?.remove()
        matchListener = db.collection("matches").document(id).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in self?.consume(snapshot: snapshot, error: error) }
        }
        startTimer()
    }

    private func consume(snapshot: DocumentSnapshot?, error: Error?) {
        guard error == nil, let data = snapshot?.data(), let uid else {
            errorMessage = "対戦データを 読み込めなかったよ"; return
        }
        let player1 = data["player1UID"] as? String ?? ""
        mySide = uid == player1 ? .human : .cpu
        let otherUID = uid == player1 ? (data["player2UID"] as? String ?? "") : player1
        if opponent?.uid != otherUID {
            Task { [weak self] in
                guard let self else { return }
                if let doc = try? await db.collection("profiles").document(otherUID).getDocument(), let values = doc.data() {
                    await MainActor.run { self.opponent = self.profile(from: values, uid: otherUID) }
                }
            }
        }
        if let encoded = data["stateData"] as? String, let bytes = Data(base64Encoded: encoded),
           let decoded = try? JSONDecoder().decode(GameState.self, from: bytes) { state = decoded }
        baseMyTime = Double(data[mySide == .human ? "player1Millis" : "player2Millis"] as? Int ?? 0) / 1000
        baseOpponentTime = Double(data[mySide == .human ? "player2Millis" : "player1Millis"] as? Int ?? 0) / 1000
        myTime = baseMyTime
        opponentTime = baseOpponentTime
        turnStartedAt = (data["turnStartedAt"] as? Timestamp)?.dateValue() ?? Date()
        matchStartsAt = (data["startsAt"] as? Timestamp)?.dateValue()
        if data["status"] as? String == "finished" {
            let winnerUID = data["winnerUID"] as? String
            let didWin = winnerUID == uid
            winner = winnerUID == uid ? mySide : mySide.opponent
            endReason = OnlineMatchEnd(rawValue: data["endReason"] as? String ?? "game") ?? .game
            didResign = data["resignedBy"] as? String == uid
            if ratingChange == nil, let rating = profile?.rating {
                ratingChange = didWin ? 16 : max(-16, -rating)
            }
            phase = .finished
            selectedSource = nil
            if !recordedResult {
                recordedResult = true
                ReviewRequestManager.requestIfEligible()
                Task { await recordResult(didWin: didWin) }
            }
        } else {
            didResign = false
            phase = .playing
            message = state.currentPlayer == mySide ? "あなたの番" : "相手の番"
#if DEBUG
            let moveNumber = data["moveNumber"] as? Int ?? 0
            if ProcessInfo.processInfo.arguments.contains("-onlineAutoPlay"), canInteract,
               moveNumber != lastAutomatedMoveNumber {
                lastAutomatedMoveNumber = moveNumber
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(350))
                    guard let self, self.canInteract,
                          let move = GameEngine.legalMoves(in: self.state).randomElement() else { return }
                    await self.send(move: move)
                }
            }
#endif
        }
    }

    private func send(move: Move) async {
        guard canInteract, let matchID, let uid else { return }
        let previous = state
        guard let next = GameEngine.applying(move, to: previous),
              let encoded = try? JSONEncoder().encode(next).base64EncodedString() else { return }
        let currentMillis = Int(myTime * 1000)
        if currentMillis <= 0 { await finishByTimeout(reason: .totalTimeout); return }
        var update: [String: Any] = [
            "stateData": encoded, "moveNumber": FieldValue.increment(Int64(1)),
            "currentUID": opponentUID ?? "", "turnStartedAt": FieldValue.serverTimestamp(), "updatedAt": FieldValue.serverTimestamp(),
            mySide == .human ? "player1Millis" : "player2Millis": currentMillis
        ]
        if case .won(let side, _) = next.result {
            update["status"] = "finished"
            update["winnerUID"] = side == mySide ? uid : (opponentUID ?? "")
            update["endReason"] = OnlineMatchEnd.game.rawValue
        }
        do {
            try await db.collection("matches").document(matchID).updateData(update)
            lastMove = move; selectedSource = nil
        } catch { errorMessage = "駒を 送れなかったよ。もう一度 試してね" }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        guard phase == .playing else { return }
        let elapsed = max(0, Date().timeIntervalSince(turnStartedAt))
        turnRemaining = max(0, Self.turnTime - elapsed)
        if state.currentPlayer == mySide { myTime = max(0, baseMyTime - elapsed) }
        else { opponentTime = max(0, baseOpponentTime - elapsed) }
        if state.currentPlayer == mySide, turnRemaining <= 0 { Task { await finishByTimeout(reason: .turnTimeout) } }
        if state.currentPlayer == mySide, myTime <= 0 { Task { await finishByTimeout(reason: .totalTimeout) } }
        if state.currentPlayer != mySide, turnRemaining <= 0 { Task { await claimOpponentTimeout(reason: .turnTimeout) } }
        if state.currentPlayer != mySide, opponentTime <= 0 { Task { await claimOpponentTimeout(reason: .totalTimeout) } }
    }

    private func finishByTimeout(reason: OnlineMatchEnd) async {
        guard let matchID else { return }
        try? await db.collection("matches").document(matchID).updateData([
            "status": "finished", "winnerUID": opponentUID ?? "", "endReason": reason.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    private func claimOpponentTimeout(reason: OnlineMatchEnd) async {
        guard let matchID, let uid else { return }
        try? await db.collection("matches").document(matchID).updateData([
            "status": "finished", "winnerUID": uid, "endReason": reason.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    private func recordResult(didWin: Bool) async {
        guard let uid, var profile else { return }
        let delta = 16
        profile.rating = max(0, profile.rating + (didWin ? delta : -delta))
        if didWin { profile.wins += 1; profile.currentStreak += 1; profile.bestStreak = max(profile.bestStreak, profile.currentStreak) }
        else { profile.losses += 1; profile.currentStreak = 0 }
        try? await db.collection("profiles").document(uid).updateData([
            "rating": profile.rating, "wins": profile.wins, "losses": profile.losses,
            "currentStreak": profile.currentStreak, "bestStreak": profile.bestStreak,
            "lastResultMatchID": matchID ?? "", "updatedAt": FieldValue.serverTimestamp()
        ])
        self.profile = profile
    }
}
