import Foundation

enum LicenseConfiguration {
    /// Official builds from `tools/release.sh` set CLOVE_LICENSED. Building from
    /// source leaves it off, so Clove stays free for anyone who builds it.
    static var isRequired: Bool {
        #if CLOVE_LICENSED
        true
        #else
        false
        #endif
    }

    static let checkoutURL = URL(string: "https://checkout.dodopayments.com/buy/pdt_0NqQSqED7xOVzkrzjXHKj?quantity=1")!
    static let apiBase = URL(string: "https://live.dodopayments.com")!

    /// Dodo's license endpoints accept any merchant's key, so a key only
    /// unlocks Clove when it was sold for one of these products.
    static let productIDs: Set<String> = ["pdt_0NqQSqED7xOVzkrzjXHKj"]

    /// How often a license is checked again, and how long Clove keeps working
    /// when it can't reach Dodo to check.
    static let revalidateAfter: Duration = .seconds(7 * 24 * 60 * 60)
    static let offlineGrace: Duration = .seconds(45 * 24 * 60 * 60)
}
