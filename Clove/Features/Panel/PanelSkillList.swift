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
            PanelSkillTable(
                rows: PanelTableRow.rows(from: model.sections),
                selectedIDs: model.selectedIDs,
                focusID: model.selectionFocusID,
                model: model
            )
        }
    }

    private func refresh() {
        Task { await model.refresh() }
    }
}
