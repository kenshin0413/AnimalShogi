import StoreKit
import UIKit

@MainActor
enum ReviewRequestManager {
    private static let lastRequestDateKey = "lastReviewRequestDate"
    private static let cooldown: TimeInterval = 15 * 24 * 60 * 60
    private static var isPending = false

    static func requestIfEligible(now: Date = Date()) {
        guard !isPending else { return }

        let defaults = UserDefaults.standard
        if let lastRequestDate = defaults.object(forKey: lastRequestDateKey) as? Date,
           now.timeIntervalSince(lastRequestDate) < cooldown {
            return
        }

        isPending = true
        Task { @MainActor in
            // 勝敗画面が表示されてから、標準レビュー画面を重ねる。
            try? await Task.sleep(for: .seconds(1))
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else {
                isPending = false
                return
            }

            defaults.set(now, forKey: lastRequestDateKey)
            SKStoreReviewController.requestReview(in: scene)
            isPending = false
        }
    }
}
