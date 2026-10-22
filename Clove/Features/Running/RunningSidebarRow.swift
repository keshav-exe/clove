import SwiftUI

struct RunningSidebarRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Label("Running", systemImage: "waveform.path.ecg")
            .badge(badge)
            .tag(SidebarItem.running)
    }

    /// From the last look; Running and Home refresh it.
    private var badge: Text? {
        let count = model.running.processes.value?.count ?? 0
        return count == 0 ? nil : Text(count, format: .number)
    }
}
