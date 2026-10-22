import SwiftUI

/// Checks every skill from skills.sh for upstream changes, then offers to update them.
struct LibraryUpdatesButton: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingUpToDate = false

    private var manager: SkillManager { model.manager }

    var body: some View {
        Group {
            if manager.updatesAvailable.isEmpty {
                Button(action: check) {
                    Label(
                        isShowingUpToDate ? "Up to Date" : "Check for Updates",
                        systemImage: isShowingUpToDate ? "checkmark.circle" : "arrow.down.circle"
                    )
                    .contentTransition(.symbolEffect(.replace))
                }
                .disabled(manager.isCheckingUpdates)
                .help(isShowingUpToDate ? "Every skill from skills.sh is up to date" : "Check skills from skills.sh for newer versions")
            } else {
                Button("Update All", systemImage: "arrow.down.circle.fill", action: updateAll)
                    .help("Update \(manager.updatesAvailable.count) skills from GitHub")
            }
        }
        .task(id: isShowingUpToDate) {
            guard isShowingUpToDate else { return }
            try? await Task.sleep(for: .seconds(2))
            isShowingUpToDate = false
        }
    }

    private func check() {
        Task {
            await manager.checkForUpdates()
            isShowingUpToDate = manager.updatesAvailable.isEmpty && manager.failure == nil
        }
    }

    private func updateAll() {
        Task { await manager.updateAll() }
    }
}
