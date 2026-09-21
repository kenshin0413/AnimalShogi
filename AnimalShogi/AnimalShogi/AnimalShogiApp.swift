//
//  AnimalShogiApp.swift
//  AnimalShogi
//
//  Created by miyamotokenshin on R 8/09/20.
//

import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAnalytics
import GoogleMobileAds

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Analytics.setAnalyticsCollectionEnabled(true)

        let adConfiguration = MobileAds.shared.requestConfiguration
        adConfiguration.ageRestrictedTreatment = .child
        adConfiguration.maxAdContentRating = GADMaxAdContentRating.general
        adConfiguration.publisherPrivacyPersonalizationState = .disabled
        MobileAds.shared.start()
        return true
    }
}

@main
struct AnimalShogiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appOpenAdManager = AppOpenAdManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if appOpenAdManager.isHoldingLaunch {
                    AppLaunchLoadingView()
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .task {
                appOpenAdManager.handleColdLaunch()
            }
        }
    }
}
