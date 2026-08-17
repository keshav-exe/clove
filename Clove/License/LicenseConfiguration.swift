import Foundation

enum LicenseConfiguration {
    /// Lemon Squeezy checkout URL for Clove. Update before shipping.
    static let purchaseURL = URL(string: "https://kshv.lemonsqueezy.com/buy/clove")!

    /// How long the app keeps working offline after the last successful validation.
    static let offlineGraceDays = 14

    /// Must match the activation limit on the Lemon Squeezy license product (recommend 2).
    static let activationLimit = 2
}
