import Foundation

enum LicenseConfiguration {
    /// Paid builds only. Alpha ships with `ReleaseConfiguration.requiresLicense = false`.
    /// Static payment link from Dodo dashboard → Products → Payment Link.
    static let purchaseURL = URL(string: "https://checkout.dodopayments.com/buy/pdt_0NmBRDBIwg3UyhKjsD7vi?quantity=1")!

    /// How long the app keeps working offline after the last successful validation.
    static let offlineGraceDays = 14

    /// Must match the activations limit on the License Key entitlement (recommend 2).
    static let activationLimit = 2
}
