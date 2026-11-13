import SwiftUI

struct LibraryList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        let results = model.libraryResults

        ListPage(selection: $model.librarySelection, order: results.map(\.id)) {
            PageHeader(title: model.libraryFilter.title, summary: summary)

            if !results.isEmpty {
                ListSection(title: model.libraryQuery.isEmpty ? "Skills" : "Matches", note: results.count.formatted()) {
                    ForEach(results) { entry in
                        SelectableRow(id: entry.id, selection: $model.librarySelection) {
                            LibraryRow(entry: entry)
                        }
                    }
                }
            }
        }
        .navigationTitle(model.libraryFilter.title)
        .searchable(text: $model.libraryQuery, prompt: "Search name, description, groups")
        .overlay {
            if model.isScanning && model.skills.isEmpty {
                ProgressView("Looking for skills")
            } else if model.catalog.isEmpty && model.didScan {
                EmptySkillsView(mode: .noSkills, onRefresh: refresh)
            } else if model.libraryResults.isEmpty {
                EmptySkillsView(mode: .noResults(model.libraryQuery), onRefresh: nil)
            }
        }
        .toolbar {
            // One group: separate items left empty glass capsules behind
            // when the column switched to another section.
            ToolbarItemGroup {
                Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                    .disabled(model.isScanning)
                    .help("Rescan your skill folders")

                if !model.manager.lockEntries.isEmpty {
                    LibraryUpdatesButton()
                }

                if case .tag(let group) = model.libraryFilter {
                    Menu {
                        ForEach(unassignedSkills(for: group)) { skill in
                            Button(skill.displayName) {
                                model.addSkillToGroup(skill, group: group)
                            }
                        }
                        if unassignedSkills(for: group).isEmpty {
                            Text("Every skill is already in this group")
                        }
                    } label: {
                        Label("Add Skills", systemImage: "plus")
                    }
                    .help("Add skills to \(group)")

                    Button("Copy Group", systemImage: "doc.on.doc") {
                        model.copyGroup(group)
                    }
                    .help("Copy all skill references in this group")
                }
            }
        }
        .onKeyPress(.return) {
            guard let skill = model.librarySelectedSkill else { return .ignored }
            model.copyReference(skill)
            return .handled
        }
    }

    private var summary: String {
        switch model.libraryFilter {
        case .all:
            return "Every SKILL.md on this Mac, from every agent. Return copies a reference, or drag one into a prompt."
        case .source(let source):
            return "Skills Clove found in \(source.sectionTitle)."
        case .tag:
            return "A group you made. Copy Group copies every reference in it at once."
        }
    }

    private func refresh() {
        Task { await model.refresh() }
    }

    private func unassignedSkills(for group: String) -> [Skill] {
        model.catalog
            .filter { entry in
                !model.tags(for: entry).contains { $0.localizedStandardCompare(group) == .orderedSame }
            }
            .map(\.primary)
    }
}
