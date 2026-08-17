import SwiftUI

struct PanelSkillList: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if model.isScanning && model.skills.isEmpty {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.skills.isEmpty && model.didScan {
            EmptySkillsView(mode: .noSkills, onRefresh: refresh)
        } else if model.visibleSkills.isEmpty {
            EmptySkillsView(mode: .noResults(model.query), onRefresh: nil)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(model.sections) { section in
                        PanelSectionHeader(title: section.title, count: section.skills.count)

                        ForEach(section.skills) { skill in
                            PanelSkillRow(skill: skill)
                                .id(skill.id)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
            .scrollIndicators(.never)
            .onChange(of: model.selectedSkills.last?.id) { _, newValue in
                guard let newValue else { return }
                withAnimation(Motion.selection(reduceMotion)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func refresh() {
        Task { await model.refresh() }
    }
}
