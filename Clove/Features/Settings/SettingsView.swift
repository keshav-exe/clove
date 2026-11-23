import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(UpdateService.self) private var updates
    @Bindable private var router = SettingsRouter.shared

    private var pane: SettingsPane { router.pane }

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selection: $router.pane)

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
        case .now: NowSettingsPane()
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
        .environment(UpdateService())
}

/// Which settings pane is showing, so other places can open Settings on one.
@MainActor
@Observable
final class SettingsRouter {
    static let shared = SettingsRouter()
    var pane: SettingsPane = .general
}

@MainActor
enum SettingsOpener {
    /// Opens Settings on the Now pane.
    static func openNow() {
        SettingsRouter.shared.pane = .now
        WindowBridge.shared.showSettings()
    }
}
