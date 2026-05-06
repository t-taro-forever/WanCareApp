//
//  BannerAdView.swift
//  WanCare
//
//  Google AdMob バナー広告ラッパー
//
//  【事前準備】
//  1. XcodeのFile > Add Package Dependencies から下記URLを追加してください：
//     https://github.com/googleads/swift-package-manager-google-mobile-ads
//  2. Info.plist に以下を追加してください：
//     GADApplicationIdentifier
//     GADBannerAdUnitID
//  3. SKAdNetworkIdentifier の追加（AdMob公式ドキュメント参照）
//
//  【広告ユニットID】
//  テスト用バナーID: ca-app-pub-3940256099942544/2934735716
//  本番用バナーID:   AdMobコンソールで作成した広告ユニットID に差し替えてください
//

import SwiftUI
import UIKit
import GoogleMobileAds

// MARK: - BannerAdView

/// AdMob バナー広告ビュー（SwiftUIラッパー）
struct BannerAdView: View {
    /// 広告ユニットID（テスト中はテスト用IDを使用）
    let adUnitID: String

    var body: some View {
        BannerAdViewRepresentable(adUnitID: adUnitID)
            .frame(height: 50)
    }
}

// MARK: - UIViewRepresentable

struct BannerAdViewRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = context.coordinator.rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = context.coordinator.rootViewController
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var rootViewController: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        }
    }
}

// MARK: - 広告ユニットID

enum AdUnitID {
    private static let plistKey = "GADBannerAdUnitID"
    static let testBanner = "ca-app-pub-3940256099942544/2934735716"

    /// Build Settings -> Info.plist へ注入された値を優先利用する。
    static var banner: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String,
           !configured.isEmpty,
           !configured.contains("xxxxxxxx") {
            return configured
        }
        #if DEBUG
        return testBanner
        #else
        assertionFailure("GADBannerAdUnitID is missing. Set ADMOB_BANNER_AD_UNIT_ID in Release config.")
        return ""
        #endif
    }
}

#Preview {
    BannerAdView(adUnitID: AdUnitID.testBanner)
}
