import SwiftUI

struct LibraryList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.librarySelection) {
            ForEach(model.libraryResults) { skill in
                LibraryRow(skill: skill)
                    .tag(skill.id)
            }
        }
        .listStyle(.inset)
        .navigationSplitViewColumnWidth(
            min: Metrics.listMinWidth,
            ideal: Metrics.listIdealWidth,
            max: 420
        )
        .navigationTitle(model.libraryFilter.title)
        .searchable(text: $model.libraryQuery, prompt: "Search name, description, tags")
        .overlay {
            if model.isScanning && model.skills.isEmpty {
                ProgressView("Looking for skills")
            } else if model.skills.isEmpty && model.didScan {
                EmptySkillsView(mode: .noSkills, onRefresh: refresh)
            } else if model.libraryResults.isEmpty {
                EmptySkillsView(mode: .noResults(model.libraryQuery), onRefresh: nil)
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                    .disabled(model.isScanning)
                    .help("Rescan your skill folders")
            }
        }
        .background {
            Button("Copy Selected Skill") {
                if let skill = model.librarySelectedSkill {
                    model.copyReference(skill)
                }
            }
            .keyboardShortcut(.return, modifiers: [])
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    private func refresh() {
        Task { await model.refresh() }
    }
}
