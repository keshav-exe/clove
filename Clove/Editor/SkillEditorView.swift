import SwiftUI

struct SkillEditorView: View {
    @Environment(AppModel.self) private var model
    @State private var editor: SkillEditorModel

    init(fileURL: URL) {
        _editor = State(initialValue: SkillEditorModel(fileURL: fileURL))
    }

    var body: some View {
        Group {
            if let error = editor.loadError {
                ContentUnavailableView(
                    "Can't Open File",
                    systemImage: "doc.questionmark",
                    description: Text(error)
                )
            } else if editor.isLoaded {
                VStack(spacing: 0) {
                    SkillEditorNotice(fileURL: editor.fileURL, folderName: editor.folderName)
                    if editor.isSkill {
                        SkillEditorFields(editor: editor)
                        Divider()
                    }
                    SkillEditorPanes(editor: editor)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(minWidth: 620, minHeight: 460)
        .navigationTitle(editor.title)
        .navigationDocument(editor.fileURL)
        .background(WindowEditedMarker(isEdited: editor.hasChanges))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $editor.mode) {
                    ForEach(SkillEditorModel.Mode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName)
                    }
                }
                .pickerStyle(.segmented)
                .labelStyle(.iconOnly)
                .help("Write, preview, or both")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save", systemImage: "square.and.arrow.down", action: save)
                    .keyboardShortcut("s")
                    .disabled(!editor.hasChanges)
                    .help("Save (⌘S)")
            }
        }
        .alert("Couldn't Save", isPresented: .constant(editor.saveError != nil)) {
            Button("OK", role: .cancel, action: editor.clearSaveError)
        } message: {
            Text(editor.saveError ?? "")
        }
        .task {
            await editor.load()
        }
        .onDisappear(perform: saveOnClose)
    }

    private func save() {
        if editor.save() {
            Task { await model.refresh() }
        }
    }

    /// Like other Mac apps, closing the window keeps your work.
    private func saveOnClose() {
        guard editor.hasChanges else { return }
        save()
    }
}
