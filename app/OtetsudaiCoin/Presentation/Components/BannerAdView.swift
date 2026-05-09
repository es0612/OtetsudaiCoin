import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = AdConstants.testBannerAdUnitID
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
