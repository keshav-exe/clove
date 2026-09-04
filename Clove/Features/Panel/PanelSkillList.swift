import SwiftUI

struct PanelSkillList: View {
    @Environment(AppModel.self) private var model

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
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(model.sections) { section in
                        PanelSectionHeader(title: section.title, count: section.entries.count)

                        ForEach(section.entries) { entry in
                            PanelSkillRow(entry: entry)
                                .id(entry.primary.id)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
            .scrollIndicators(.never)
            .onChange(of: model.selectionFocusID) {
                revealSelection(proxy)
            }
            .onChange(of: model.query) {
                revealSelection(proxy)
            }
            .onChange(of: model.activeTag) {
                revealSelection(proxy)
            }
            .onChange(of: model.displayTick) {
                revealSelection(proxy)
            }
        }
    }

    private func revealSelection(_ proxy: ScrollViewProxy) {
        guard let id = model.selectionFocusID ?? model.selectedSkills.last?.id else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(id)
        }
    }

    private func refresh() {
        Task { await model.refresh() }
    }
}
