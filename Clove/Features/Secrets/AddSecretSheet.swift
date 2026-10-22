import SwiftUI

struct AddSecretSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var value = ""

    private var isValid: Bool {
        SecretVault.isValidName(name) && !value.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("OPENAI_API_KEY"))
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                    SecureField("Value", text: $value)
                } footer: {
                    Text("Saved to your login Keychain. Clove never writes it to a file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save Key", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding(Metrics.spacingL)
        }
        .frame(width: 440, height: 260)
    }

    private func save() {
        if model.secrets.save(value, named: name.trimmingCharacters(in: .whitespaces)) {
            dismiss()
        }
    }
}
