import SwiftUI

struct SkillUpdateRow: View {
    @Environment(AppModel.self) private var model
    let name: String

    private var manager: SkillManager { model.manager }

    var body: some View {
        HStack(spacing: Metrics.spacingS) {
            if let phase = manager.phase(for: name) {
                ProgressView()
                    .controlSize(.small)
                Text(phase == .removing ? "Removing…" : "Updating…")
                    .foregroundStyle(.secondary)
            } else if manager.hasUpdate(name) {
                Button("Update", systemImage: "arrow.down.circle", action: update)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Text("A newer version is on GitHub.")
                    .foregroundStyle(.secondary)
            } else if manager.isCheckingUpdates {
                ProgressView()
                    .controlSize(.small)
                Text("Checking for updates…")
                    .foregroundStyle(.secondary)
            } else if let checked = manager.lastUpdateCheck {
                Text("Up to date as of \(checked, format: .dateTime.hour().minute())")
                    .foregroundStyle(.secondary)
            } else {
                Button("Check for Updates", action: check)
                    .controlSize(.small)
            }
        }
    }

    private func update() {
        Task { await manager.update(name) }
    }

    private func check() {
        Task { await manager.checkForUpdates() }
    }
}
