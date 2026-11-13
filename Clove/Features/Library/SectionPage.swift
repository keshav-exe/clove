import SwiftUI

/// The one page beside the sidebar. Overviews (Home, Cleanup, Storage) are a
/// single scrolling page; lists open what you pick in an inspector on the
/// right, and closing it clears the selection.
struct SectionPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        switch model.section {
        case .home:
            HomeView()
        case .cleanup:
            CleanupSummary()
        case .storage:
            StoragePage()
        case .library:
            LibraryList()
                .inspected(isPresented: presence($model.librarySelection)) { LibraryDetail() }
        case .discover:
            @Bindable var store = model.marketplace
            DiscoverList()
                .inspected(isPresented: presence($store.selection)) { DiscoverDetail() }
        case .resources(let kind):
            ResourceList(kind: kind)
                .inspected(isPresented: presence($model.resourceSelection)) { ResourceDetailColumn() }
        case .secrets:
            @Bindable var secrets = model.secrets
            SecretsList()
                .inspected(isPresented: Binding {
                    secrets.selection != nil || (secrets.isShowingFindings && !secrets.findings.isEmpty)
                } set: { isShowing in
                    if !isShowing {
                        secrets.selection = nil
                        secrets.isShowingFindings = false
                    }
                }) { SecretDetail() }
        case .running:
            @Bindable var running = model.running
            RunningList()
                .inspected(isPresented: presence($running.selection)) { RunningDetail() }
        }
    }

    /// Open while something is selected; closing deselects.
    private func presence<ID>(_ selection: Binding<ID?>) -> Binding<Bool> {
        Binding {
            selection.wrappedValue != nil
        } set: { isShowing in
            if !isShowing { selection.wrappedValue = nil }
        }
    }
}

extension View {
    /// Detail in the native trailing inspector, sized for a skill's SKILL.md.
    func inspected<Detail: View>(isPresented: Binding<Bool>, @ViewBuilder detail: () -> Detail) -> some View {
        inspector(isPresented: isPresented) {
            detail()
                .inspectorColumnWidth(min: 320, ideal: 400, max: 600)
        }
    }
}
