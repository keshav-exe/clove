import AppKit
import SwiftUI

struct AboutSettingsPane: View {
    @Environment(AppModel.self) private var model
    @Environment(UpdateService.self) private var updates
    @State private var whatsNewRelease: WhatsNewRelease?
    @State private var offeredUpdate: UpdateManifest?
    @State private var updateNotice: UpdateNotice?

    var body: some View {
        SettingsForm(centered: true) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsFieldRow(label: "Version") {
                    Text(AppVersion.display)
                }

                if ReleaseConfiguration.isAlpha {
                    SettingsFieldRow(label: "Channel") {
                        Text(ReleaseConfiguration.channelName)
                    }
                }

                SettingsFieldRow(label: "Updates") {
                    if updates.isChecking {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Check for Updates…", action: checkForUpdates)
                    }
                }

                SettingsFieldRow(label: "What's New") {
                    Button("Show Release Notes…") {
                        whatsNewRelease = WhatsNewCatalog.latest
                    }
                }

                SettingsPaneDivider()

                SettingsFieldRow(label: "Skills indexed") {
                    Text("\(model.skills.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                SettingsFieldRow(label: "Groups in use") {
                    Text("\(model.allGroups.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: $whatsNewRelease) { release in
            WhatsNewSheet(release: release) {
                model.settings.lastSeenWhatsNewVersion = release.version
            }
        }
        .sheet(item: $offeredUpdate, onDismiss: skipUpdateIfStillPending) { update in
            UpdateAvailableSheet(update: update)
        }
        .alert(item: $updateNotice) { notice in
            switch notice {
            case .upToDate:
                Alert(
                    title: Text("You're up to date"),
                    message: Text("Clove \(AppVersion.display) is the latest version."),
                    dismissButton: .default(Text("OK"))
                )
            case let .error(message):
                Alert(
                    title: Text("Couldn't Check for Updates"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func checkForUpdates() {
        Task {
            await updates.checkForUpdates(userInitiated: true)
            if let update = updates.availableUpdate {
                offeredUpdate = update
            } else if let error = updates.lastCheckError {
                updateNotice = .error(error)
            } else {
                updateNotice = .upToDate
            }
        }
    }

    private func skipUpdateIfStillPending() {
        guard let update = updates.availableUpdate else { return }
        updates.dismiss(update)
    }
}

private enum UpdateNotice: Identifiable {
    case upToDate
    case error(String)

    var id: String {
        switch self {
        case .upToDate: "upToDate"
        case let .error(message): "error-\(message)"
        }
    }
}
