import SwiftUI

/// Plain-text keys found in shell profiles, with one action to move them.
struct PlaintextFindingsView: View {
    @Environment(AppModel.self) private var model
    @State private var kept: Set<String> = []
    @State private var isConfirming = false

    private var findings: [PlaintextSecretFinder.Finding] { model.secrets.findings }
    private var chosen: [PlaintextSecretFinder.Finding] { findings.filter { !kept.contains($0.id) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    Label("Keys in plain text", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text("Any app or script that can read your home folder can read these. Move them to the Keychain and your profile looks them up instead, with macOS asking first.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    ForEach(findings) { finding in
                        Toggle(isOn: Binding(
                            get: { !kept.contains(finding.id) },
                            set: { isOn in if isOn { kept.remove(finding.id) } else { kept.insert(finding.id) } }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(finding.name)
                                    .font(.body.monospaced())
                                Text("~/\(finding.file.lastPathComponent), line \(finding.line + 1) · \(Self.masked(finding.value))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if finding.id != findings.last?.id {
                            Divider().opacity(0.45)
                        }
                    }
                }

                Button("Move \(chosen.count) to Keychain", systemImage: "lock") { isConfirming = true }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(chosen.isEmpty)
            }
            .padding(Metrics.spacingXL)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Secrets")
        .confirmationDialog("Move \(chosen.count) keys to the Keychain?", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Move to Keychain") { model.secrets.moveToKeychain(chosen) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Each line becomes a Keychain lookup. A copy of the old profile goes to the Trash. New terminal windows pick up the change.")
        }
    }

    /// Enough to recognize the key, not enough to use it.
    static func masked(_ value: String) -> String {
        guard value.count > 8 else { return "••••" }
        return String(value.prefix(3)) + "…" + String(value.suffix(4))
    }
}
