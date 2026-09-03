import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(UpdateService.self) private var updates
    @State private var pane: SettingsPane = .general

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selection: $pane)

            Divider()

            Text(pane.title)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.top, Metrics.spacingM)
                .padding(.bottom, Metrics.spacingS)
                .accessibilityAddTraits(.isHeader)

            paneView(pane)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(pane)
        }
        .frame(width: Metrics.settingsWidth, height: Metrics.settingsHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func paneView(_ pane: SettingsPane) -> some View {
        switch pane {
        case .general: GeneralSettingsPane()
        case .sources: SourcesSettingsPane()
        case .shortcuts: ShortcutsSettingsPane()
        case .privacy: PrivacySettingsPane()
        case .about: AboutSettingsPane()
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel.preview)
        .environment(UpdateService(settings: AppModel.preview.settings))
}
