import Foundation

enum OnlineRank: String, CaseIterable, Codable {
    case egg = "たまご"
    case chick = "ひよこ"
    case rabbit = "うさぎ"
    case fox = "きつね"
    case wolf = "おおかみ"
    case lion = "らいおん"
    case dinosaur = "きょうりゅう"

    static func rank(for rating: Int) -> Self {
        switch rating {
        case ..<800: .egg
        case ..<1000: .chick
        case ..<1200: .rabbit
        case ..<1400: .fox
        case ..<1600: .wolf
        case ..<1800: .lion
        default: .dinosaur
        }
    }
}

struct OnlineProfile: Equatable {
    static let icons = ["Dinosaur", "Crab", "Snake", "Minnow", "Fish", "Rabbit", "Dog", "Bear"]

    let uid: String
    var name: String
    var icon: String
    var rating: Int
    var wins: Int
    var losses: Int
    var draws: Int
    var currentStreak: Int
    var bestStreak: Int

    var rank: OnlineRank { .rank(for: rating) }
    var games: Int { wins + losses + draws }
}

enum OnlineMatchPhase: Equatable {
    case profile
    case ready
    case searching
    case playing
    case finished
}

enum OnlineMatchEnd: String {
    case game
    case resignation
    case turnTimeout
    case totalTimeout
    case disconnected
    case invalidState

    var label: String {
        switch self {
        case .game: "勝負が ついたよ"
        case .resignation: "降参"
        case .turnTimeout: "60秒 たったよ"
        case .totalTimeout: "持ち時間が なくなったよ"
        case .disconnected: "接続が 切れたよ"
        case .invalidState: "データが 合わなかったよ"
        }
    }
}

enum NameValidator {
    static let maximumLength = 10
    private static let blockedFragments = [
        "ばか", "バカ", "あほ", "アホ", "しね", "死ね", "ころす", "殺す",
        "くそ", "クソ", "うんこ", "ちんこ", "まんこ", "せっくす", "セックス",
        "運営", "公式", "admin", "administrator", "http", "www", "line", "instagram",
        "twitter", "discord", "メール", "でんわ", "電話"
    ]

    static func error(for rawName: String) -> String? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...maximumLength).contains(trimmed.count) else { return "名前は 2〜10文字にしてね" }
        guard !trimmed.contains("\n"), !trimmed.contains("\r") else { return "改行は 使えないよ" }
        let normalized = normalizedForCheck(trimmed)
        guard !blockedFragments.contains(where: { normalized.contains(normalizedForCheck($0)) }) else {
            return "その名前は 使えないよ"
        }
        let digits = normalized.filter(\.isNumber)
        guard digits.count < 7 else { return "電話番号は 入れないでね" }
        guard normalized.range(of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: .regularExpression) == nil else {
            return "メールアドレスは 入れないでね"
        }
        return nil
    }

    static func normalizedForCheck(_ value: String) -> String {
        value.precomposedStringWithCompatibilityMapping
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
