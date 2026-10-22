import SwiftUI

/// Starts a skill from a name, a description, and a template, then opens it in the editor.
struct NewSkillSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var title = ""
    @State private var description = ""
    @State private var template: SkillTemplate = .guide
    @State private var targets: Set<AgentTarget> = []
    @State private var failure: ManagerFailure?
    @State private var isCreating = false

    private var name: String {
        SkillDocumentIssue.slug(from: title)
    }

    private var document: SkillDocument {
        SkillDocument(name: name, description: description, body: template.body(title: title.isEmpty ? name : title))
    }

    private var blockingIssues: [SkillDocumentIssue] {
        SkillDocumentIssue.issues(in: document, folderName: nil).filter { $0.severity == .error }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $title, prompt: Text("Release Notes"))
                    LabeledContent("Reference") {
                        Text(name.isEmpty ? "—" : "/\(name)")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    TextField(
                        "Description",
                        text: $description,
                        prompt: Text("Writes release notes from merged pull requests. Use when preparing a release."),
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                } footer: {
                    Text("Agents read the description to decide when to load the skill. Say what it does and when to use it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Start From") {
                    Picker("Template", selection: $template) {
                        ForEach(SkillTemplate.allCases) { template in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(template.title)
                                Text(template.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(template)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                Section {
                    ForEach(AgentTarget.allCases) { target in
                        Toggle(target.title, isOn: binding(for: target))
                    }
                } header: {
                    Text("Use In")
                } footer: {
                    Text("Saved to ~/.agents/skills/\(name.isEmpty ? "…" : name) and linked into each agent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            NewSkillFooter(
                failure: failure,
                isCreating: isCreating,
                canCreate: blockingIssues.isEmpty && !targets.isEmpty,
                cancel: cancel,
                create: create
            )
        }
        .frame(width: 520, height: 700)
        .onAppear(perform: loadTargets)
    }

    private func binding(for target: AgentTarget) -> Binding<Bool> {
        Binding {
            targets.contains(target)
        } set: { isOn in
            if isOn { targets.insert(target) } else { targets.remove(target) }
        }
    }

    private func loadTargets() {
        targets = model.manager.defaultTargets
    }

    private func cancel() {
        dismiss()
    }

    private func create() {
        isCreating = true
        failure = nil
        Task {
            defer { isCreating = false }
            switch await model.manager.create(document, targets: targets) {
            case .success(let file):
                dismiss()
                openWindow(id: CloveWindowID.editor, value: file)
            case .failure(let error):
                failure = error
            }
        }
    }
}
