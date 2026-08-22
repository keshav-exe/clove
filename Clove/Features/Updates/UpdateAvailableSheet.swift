import AppKit
import SwiftUI

struct UpdateAvailableSheet: View {
    @Environment(UpdateService.self) private var updates
    @Environment(\.dismiss) private var dismiss

    let update: UpdateManifest

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Update Available")
                        .font(.title3.weight(.semibold))

                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 8) {
                Button("Install Now") {
                    updates.installNow(update)
                    dismiss()
                }
                .buttonStyle(UpdatePillButtonStyle())
                .keyboardShortcut(.defaultAction)

                Button("Install on Next Launch") {
                    updates.installOnNextLaunch(update)
                    dismiss()
                }
                .buttonStyle(UpdatePillButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 360)
        .presentationBackground(.regularMaterial)
    }

    private var message: String {
        if let releaseNotes = update.releaseNotes, !releaseNotes.isEmpty {
            releaseNotes
        } else {
            "A new version of Clove (\(update.version)) is ready to be installed."
        }
    }
}

private struct UpdatePillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .opacity(configuration.isPressed ? 0.82 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    UpdateAvailableSheet(
        update: UpdateManifest(
            version: "0.2",
            downloadURL: URL(string: "https://example.com/Clove.dmg")!,
            releaseNotes: "A new version of Clove is ready to be installed."
        )
    )
    .environment(UpdateService(settings: SettingsStore()))
}
