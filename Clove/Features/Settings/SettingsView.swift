import SwiftUI

/// Clove's settings, in the window every Mac app uses for them: a toolbar of
/// panes across the top, each a grouped form.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(UpdateService.self) private var updates
    @Bindable private var router = SettingsRouter.shared

    var body: some View {
        TabView(selection: $router.pane) {
            ForEach(SettingsPane.visibleCases) { pane in
                paneView(pane)
                    .tabItem { Label(pane.title, systemImage: pane.symbolName) }
                    .tag(pane)
            }
        }
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
