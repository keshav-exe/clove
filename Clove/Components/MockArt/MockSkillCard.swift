import SwiftUI

/// A skill as the library lists it: reference, a line of description, where it's installed.
struct MockSkillCard: View {
    let reference: String
    let summary: String
    var badges: [(String, Color)] = [("Claude Code", .orange)]

    var body: some View {
        MockCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(reference)
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    ForEach(badges.indices, id: \.self) { index in
                        Text(badges[index].0)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(badges[index].1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badges[index].1.opacity(0.13), in: .capsule)
                    }
                }
            }
        }
    }
}
