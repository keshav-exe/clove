import SwiftUI

struct SecretDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let secrets = model.secrets
        Group {
            if let name = secrets.selection, secrets.items.contains(where: { $0.name == name }) {
                SecretDetailView(name: name)
                    .id(name)
            } else if !secrets.findings.isEmpty {
                PlaintextFindingsView()
            } else if secrets.items.isEmpty {
                Color.clear
            } else {
                CalmEmptyState(
                    title: "Pick a key",
                    message: "You'll get a line for your shell and a command for MCP servers. Neither writes the key down."
                ) {
                    SecretsArt()
                }
            }
        }
        .alert(
            secrets.failure?.title ?? "",
            isPresented: Binding(get: { secrets.failure != nil }, set: { if !$0 { secrets.failure = nil } }),
            presenting: secrets.failure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
    }
}
