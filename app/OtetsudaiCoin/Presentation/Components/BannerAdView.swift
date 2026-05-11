import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = AdConstants.bannerAdUnitID
        bannerView.load(Self.makeNonPersonalizedRequest())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    // Issue #22: ATT 対応として Non-personalized 広告のみで運用する。
    // 起動時にトラッキング許可ダイアログを出さず、IDFA を利用しない設定で広告を要求する。
    static func makeNonPersonalizedExtras() -> Extras {
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        return extras
    }

    static func makeNonPersonalizedRequest() -> Request {
        let request = Request()
        request.register(makeNonPersonalizedExtras())
        return request
    }
}
