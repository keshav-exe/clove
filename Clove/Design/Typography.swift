import SwiftUI

/// The web system's type roles, set in SF Pro so the app stays native. SF
/// tracks itself optically, so nothing here adds letter-spacing.
extension View {
    /// A page or card headline: semibold, the site's display role.
    func display(_ size: CGFloat) -> some View {
        font(.system(size: size, weight: .semibold))
    }

    /// Body copy on custom surfaces.
    func prose(_ size: CGFloat = 13, _ weight: Font.Weight = .regular) -> some View {
        font(.system(size: size, weight: weight))
    }

    /// Counts, sizes, dates: the site's mono label, as tabular SF digits.
    func monoLabel(_ size: CGFloat = 11) -> some View {
        font(.system(size: size).monospacedDigit())
    }

    /// Paths and identifiers, where a fixed width helps the eye: SF Mono.
    func codeLabel(_ size: CGFloat = 11) -> some View {
        font(.system(size: size, design: .monospaced))
    }
}
