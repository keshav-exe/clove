import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var pane: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $pane) {
                Section {
                    ForEach(SettingsPane.allCases) { item in
                        Label {
                            Text(item.title)
                        } icon: {
                            SettingsSidebarIcon(systemImage: item.symbolName, tint: item.tint)
                        }
                        .tag(item)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(width: Metrics.settingsSidebarWidth)

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: Metrics.settingsWidth, height: Metrics.settingsHeight)
    }

    @ViewBuilder
    private var detail: some View {
        switch pane {
        case .general: GeneralSettingsPane()
        case .sources: SourcesSettingsPane()
        case .shortcuts: ShortcutsSettingsPane()
        case .privacy: PrivacySettingsPane()
        case .license: LicenseSettingsPane()
        case .about: AboutSettingsPane()
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel.preview)
}
