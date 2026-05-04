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
//     Key: GADApplicationIdentifier
//     Value: ca-app-pub-3940256099942544~1458002511  ← テスト用AppID（本番は実際のIDに変更）
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

// MARK: - 広告ユニットID 定数

enum AdUnitID {
    /// テスト用バナーID（開発中はこちらを使用）
    static let testBanner = "ca-app-pub-3940256099942544/2934735716"

    /// 本番用バナーID（リリース時はAdMobコンソールのIDに差し替え）
    static let productionBanner = "YOUR_PRODUCTION_BANNER_AD_UNIT_ID"

    /// 現在使用するID（デバッグ/シミュレータ: testBanner、本番実機: productionBanner）
    static var banner: String {
        #if DEBUG
        return testBanner
        #else
        #if targetEnvironment(simulator)
        return testBanner
        #else
        return productionBanner
        #endif
        #endif
    }
}

#Preview {
    BannerAdView(adUnitID: AdUnitID.testBanner)
}
