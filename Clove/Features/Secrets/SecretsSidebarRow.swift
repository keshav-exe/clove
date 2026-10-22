import SwiftUI

struct SecretsSidebarRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Label("Secrets", systemImage: "key")
            .badge(badge)
            .tag(SidebarItem.secrets)
            .task {
                model.secrets.load()
            }
    }

    /// Plain-text keys outrank the count of saved ones: they're the thing to fix.
    private var badge: Text? {
        let exposed = model.secrets.findings.count
        if exposed > 0 {
            return Text("\(exposed) exposed").foregroundStyle(.orange)
        }
        let count = model.secrets.items.count
        return count == 0 ? nil : Text(count, format: .number)
    }
}
