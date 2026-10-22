import SwiftUI

/// A markdown file: its name, the agent that reads it, and a few lines of
/// content where headings stand out and body lines are soft bars.
struct MockFileCard: View {
    let fileName: String
    var agent: (String, Color) = ("Any Agent", .secondary)
    var lines: [String] = ["## Commands", "", "", "## Conventions", ""]

    var body: some View {
        MockCard {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: "text.document")
                        .foregroundStyle(Palette.inkTertiary)
                    Text(fileName)
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 4)
                    Text(agent.0)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(agent.1)
                }
                ForEach(lines.indices, id: \.self) { index in
                    let line = lines[index]
                    if line.isEmpty {
                        // Text the eye reads as text without spelling it out.
                        Capsule()
                            .fill(Palette.surfaceMuted)
                            .frame(width: index % 2 == 0 ? 168 : 128, height: 6)
                    } else {
                        Text(line)
                            .font(.caption2.weight(.semibold).monospaced())
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
        }
    }
}
