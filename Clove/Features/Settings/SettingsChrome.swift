import SwiftUI

enum SettingsLayout {
    static let labelWidth: Double = 112
    static let contentMaxWidth: Double = 360
    static let shortcutKeyWidth: Double = 132
}

// MARK: - Tab bar

struct SettingsTabBar: View {
    @Binding var selection: SettingsPane
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Metrics.spacingXS) {
            ForEach(SettingsPane.visibleCases) { pane in
                SettingsTabButton(
                    pane: pane,
                    isSelected: selection == pane
                ) {
                    selection = pane
                }
            }
        }
        .padding(.horizontal, Metrics.spacingL)
        .padding(.vertical, Metrics.spacingM)
        .animation(Motion.selection(reduceMotion), value: selection)
    }
}

private struct SettingsTabButton: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: pane.symbolName)
                    .font(.system(size: 17, weight: .medium))
                    .symbolRenderingMode(.hierarchical)

                Text(pane.title)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Sections

struct SettingsSection<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            content()

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsInsetGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: Metrics.rowRadius + 1, style: .continuous))
    }
}

struct SettingsPaneDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, Metrics.spacingS)
    }
}

// MARK: - Rows

struct SettingsCheckboxRow: View {
    let title: String
    @Binding var isOn: Bool
    var isDisabled = false

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.callout)
        }
        .toggleStyle(.checkbox)
        .disabled(isDisabled)
        .padding(.vertical, 3)
    }
}

struct SettingsFieldRow<Value: View>: View {
    let label: String
    @ViewBuilder let value: () -> Value

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingM) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: SettingsLayout.labelWidth, alignment: .trailing)

            value()

            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.vertical, 5)
    }
}

struct SettingsShortcutRow: View {
    let action: String
    let keys: String

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            Text(action)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(keys)
                .frame(width: SettingsLayout.shortcutKeyWidth, alignment: .leading)
        }
        .font(.callout)
        .padding(.vertical, 4)
    }
}

struct SettingsPromiseRow: View {
    let promise: PrivacyPromise

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacingM) {
            Image(systemName: promise.symbolName)
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(promise.title)
                    .font(.callout)

                Text(promise.detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}
