import SwiftUI

/// A Keychain entry: the variable name, a masked value, the lock.
struct MockKeyCard: View {
    let name: String

    var body: some View {
        MockCard(width: 220) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name)
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 4)
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(Palette.accent)
                }
                Text(String(repeating: "•", count: 18))
                    .font(.caption.monospaced())
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }
}
