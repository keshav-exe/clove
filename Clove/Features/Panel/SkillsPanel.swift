import SwiftUI

struct SkillsPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focus: PanelFocus?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(focus: $focus)

            Divider()
                .opacity(0.6)

            if model.activeTag != nil {
                PanelFilterPill()
            }

            PanelSkillList()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .opacity(0.6)

            PanelFooter(focus: $focus)
        }
        .frame(
            minWidth: Metrics.panelMinWidth,
            idealWidth: Metrics.panelWidth,
            maxWidth: Metrics.panelMaxWidth,
            minHeight: Metrics.panelMinHeight,
            idealHeight: Metrics.panelHeight,
            maxHeight: Metrics.panelMaxHeight
        )
        .task {
            await model.startIfNeeded()
            focus = .search
        }
        .onChange(of: model.query) {
            model.ensureSelectionVisible()
        }
        .onChange(of: model.displayTick) {
            focus = .search
        }
        .onChange(of: focus) {
            model.activeFocus = focus
        }
        .onChange(of: model.focusTick) {
            focus = model.focusTarget
        }
        .animation(Motion.selection(reduceMotion), value: model.selectedIDs)
        .animation(Motion.selection(reduceMotion), value: model.activeTag)
        .defaultFocus($focus, .search)
    }

}

#Preview {
    SkillsPanel()
        .environment(AppModel.preview)
        .frame(width: Metrics.panelWidth, height: Metrics.panelHeight)
}
