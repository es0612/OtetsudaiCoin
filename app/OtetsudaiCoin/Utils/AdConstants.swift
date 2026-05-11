import Foundation

enum AdConstants {
    static var applicationIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
    }

    static var bannerAdUnitID: String {
        Bundle.main.object(forInfoDictionaryKey: "GADBannerAdUnitID") as? String ?? ""
    }
}
