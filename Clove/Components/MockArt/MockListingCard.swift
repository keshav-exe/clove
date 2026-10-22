import SwiftUI

/// A skills.sh listing: name, owner, installs, and the Install button.
struct MockListingCard: View {
    let name: String
    let owner: String
    let installs: String

    var body: some View {
        MockCard {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text(owner)
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSecondary)
                }
                HStack {
                    Label(installs, systemImage: "arrow.down.circle")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Palette.inkSecondary)
                    Spacer(minLength: 4)
                    Text("Install")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Palette.accent, in: .capsule)
                }
            }
        }
    }
}
