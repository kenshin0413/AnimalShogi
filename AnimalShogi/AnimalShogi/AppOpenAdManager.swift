import Combine
import GoogleMobileAds
import SwiftUI

/// 起動画面の表示中にだけ広告を出す。読み込みが遅れた広告で、
/// ホームや対局を後から遮らないように管理する。
@MainActor
final class AppOpenAdManager: NSObject, ObservableObject {
    static let shared = AppOpenAdManager()

    @Published private(set) var isHoldingLaunch = false

    private let launchCountKey = "appLaunchCount"
    private let maximumWaitNanoseconds: UInt64 = 3_000_000_000
    private var appOpenAd: AppOpenAd?
    private var launchToken = UUID()
    private var hasHandledColdLaunch = false

    #if DEBUG
    // 開発中に本番広告を誤タップしないため、Google公式テストIDを使う。
    private let adUnitID = "ca-app-pub-3940256099942544/5575463023"
    #else
    private let adUnitID = "ca-app-pub-2277987033120510/2579593073"
    #endif

    func handleColdLaunch() {
        guard !hasHandledColdLaunch else { return }
        hasHandledColdLaunch = true

        let defaults = UserDefaults.standard
        let previousLaunchCount = defaults.integer(forKey: launchCountKey)
        defaults.set(previousLaunchCount + 1, forKey: launchCountKey)

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let forceFirstLaunch = arguments.contains("-forceFirstLaunch")
        let forceReturningLaunch = arguments.contains("-forceReturningLaunch")
        #else
        let forceFirstLaunch = false
        let forceReturningLaunch = false
        #endif

        let tutorialFinished = defaults.bool(forKey: "hasSeenInteractiveTutorial")
        let shouldProtectFirstExperience = previousLaunchCount == 0 || !tutorialFinished
        let shouldSkipAd = forceFirstLaunch || (!forceReturningLaunch && shouldProtectFirstExperience)
        guard !shouldSkipAd else {
            AnalyticsService.appOpenAdEvent("app_open_ad_first_skip")
            return
        }

        isHoldingLaunch = true
        let token = UUID()
        launchToken = token

        Task { [weak self] in
            guard let self else { return }
            do {
                let ad = try await AppOpenAd.load(with: adUnitID, request: Request())
                guard launchToken == token, isHoldingLaunch else { return }
                appOpenAd = ad
                ad.fullScreenContentDelegate = self
                AnalyticsService.appOpenAdEvent("app_open_ad_loaded")
                ad.present(from: nil)
            } catch {
                guard launchToken == token else { return }
                AnalyticsService.appOpenAdEvent(
                    "app_open_ad_load_fail",
                    errorCode: (error as NSError).code
                )
                finishLaunch(token: token)
            }
        }

        let timeout = maximumWaitNanoseconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeout)
            guard let self, launchToken == token, isHoldingLaunch, appOpenAd == nil else { return }
            AnalyticsService.appOpenAdEvent("app_open_ad_timeout")
            finishLaunch(token: token)
        }
    }

    private func finishLaunch(token: UUID? = nil) {
        if let token, token != launchToken { return }
        launchToken = UUID()
        appOpenAd = nil
        withAnimation(.easeOut(duration: 0.18)) {
            isHoldingLaunch = false
        }
    }
}

extension AppOpenAdManager: FullScreenContentDelegate {
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        AnalyticsService.appOpenAdEvent("app_open_ad_impression")
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        AnalyticsService.appOpenAdEvent("app_open_ad_click")
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        AnalyticsService.appOpenAdEvent("app_open_ad_present")
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        AnalyticsService.appOpenAdEvent("app_open_ad_dismiss")
        finishLaunch()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        AnalyticsService.appOpenAdEvent(
            "app_open_ad_present_fail",
            errorCode: (error as NSError).code
        )
        finishLaunch()
    }
}

struct AppLaunchLoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.37, green: 0.76, blue: 0.91), Color(red: 0.74, green: 0.88, blue: 0.39)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("いきものしょうぎ")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.16), radius: 3, y: 2)

                Text("Ikimono Shogi")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.15)
                    .padding(.top, 12)

                Text("じゅんび中…")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ゲームをじゅんび中")
    }
}
