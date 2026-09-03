import SwiftUI

struct GroupSuggestionRow: View {
    let suggestion: GroupSuggestion
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if case .create = suggestion {
                Text("New")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isHighlighted ? Color.primary.opacity(0.08) : .clear,
            in: .rect(cornerRadius: 6)
        )
        .contentShape(.rect)
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
        .accessibilityLabel(accessibilityTitle)
    }

    private var title: String {
        switch suggestion {
        case .existing(let name):
            name
        case .create(let name):
            name
        }
    }

    private var accessibilityTitle: String {
        switch suggestion {
        case .existing(let name):
            name
        case .create(let name):
            "Create \(name)"
        }
    }
}
