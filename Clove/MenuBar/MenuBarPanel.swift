import SwiftUI

/// Menu bar mode's panel: the notch's tabs and content, without the notch.
/// Same width as the island, and the same tallest tab, so both modes feel
/// like one thing.
struct MenuBarPanel: View {
    static let stripHeight: CGFloat = 36
    static let size = CGSize(width: NotchModel.panelWidth, height: stripHeight + NotchModel.contentHeight)

    @Environment(AppModel.self) private var model

    var body: some View {
        let tab = model.settings.currentTab

        VStack(spacing: 0) {
            PanelTabStrip()
                .frame(height: Self.stripHeight)
                .padding(.top, 2)
            if model.isPanelVisible {
                PanelBlockContent(block: tab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .id(tab)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
