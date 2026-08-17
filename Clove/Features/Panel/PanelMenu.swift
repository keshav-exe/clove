import SwiftUI

struct PanelMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel

    var body: some View {
        Menu {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await model.refresh() }
            }

            Button("Skill Library…", systemImage: "square.stack.3d.up") {
                closePanel()
                WindowBridge.shared.showLibraryWindow()
            }

            Divider()

            Button("Settings…", systemImage: "gearshape") {
                closePanel()
                WindowBridge.shared.showSettings()
            }

            Button("Quit Clove", systemImage: "power", action: model.quit)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .accessibilityLabel("More actions")
    }
}
