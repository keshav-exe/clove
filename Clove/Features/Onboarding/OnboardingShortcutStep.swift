import SwiftUI

struct OnboardingShortcutStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                FeatureHighlightRow(
                    highlight: FeatureHighlight(
                        symbolName: "command",
                        title: "Global shortcut",
                        detail: "Opens the quick access panel from any app."
                    )
                )

                Toggle("Global shortcut", isOn: $settings.hotKeyEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28, height: 28)

                Text("Shortcut")
                    .font(.body.weight(.medium))

                Spacer(minLength: 8)

                KeyRecorderView(chord: $settings.hotKey)
            }
            .disabled(!settings.hotKeyEnabled)
            .opacity(settings.hotKeyEnabled ? 1 : 0.5)
            .padding(.leading, 2)

            if settings.hotKeyEnabled, settings.hotKey != nil, !settings.hotKeyIsRegistered {
                Label(
                    "Another app is already using that shortcut. Pick a different one.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .symbolRenderingMode(.hierarchical)
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Divider()

            HStack(alignment: .top) {
                FeatureHighlightRow(
                    highlight: FeatureHighlight(
                        symbolName: "menubar.arrow.up.rectangle",
                        title: "Menu bar icon",
                        detail: "Keeps Clove one click away, even when the window is closed."
                    )
                )

                Toggle("Menu bar icon", isOn: $settings.showMenuBarIcon)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .padding(.top, 4)
            }

            Text("You can change all of this later in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
