import SwiftUI

struct OnboardingShortcutStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        VStack(alignment: .leading, spacing: 18) {
            OnboardingRow(
                systemImage: "command",
                title: "Global shortcut",
                detail: "Opens the quick access panel from any app."
            ) {
                Toggle("Global shortcut", isOn: $settings.hotKeyEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            HStack(spacing: 14) {
                OnboardingTile(systemImage: "keyboard")

                Text("Shortcut")
                    .font(.callout.weight(.semibold))

                Spacer(minLength: 8)

                KeyRecorderView(chord: $settings.hotKey)
            }
            .disabled(!settings.hotKeyEnabled)
            .opacity(settings.hotKeyEnabled ? 1 : 0.5)

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

            OnboardingRow(
                systemImage: "menubar.arrow.up.rectangle",
                title: "Menu bar icon",
                detail: "Keeps Clove one click away, even when the window is closed."
            ) {
                Toggle("Menu bar icon", isOn: $settings.showMenuBarIcon)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Text("You can change all of this later in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
