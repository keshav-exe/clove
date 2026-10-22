import SwiftUI

struct CleanupLeftoverGroup: View {
    @Environment(AppModel.self) private var model
    let kind: LeftoverKind
    let items: [LeftoverItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            Text(kind.title)
                .font(.callout.weight(.semibold))
            Text(kind.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    Toggle(isOn: Binding(get: { model.cleanup.isSelected(item) }, set: { _ in model.cleanup.toggle(item) })) {
                        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingM) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: Metrics.spacingM)
                            Text(CleanupLeftoversCard.bytes(item.bytes))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(.vertical, 5)
                    .help(item.url.path(percentEncoded: false))
                }
            }
            .padding(.top, Metrics.spacingXS)
        }
    }
}
