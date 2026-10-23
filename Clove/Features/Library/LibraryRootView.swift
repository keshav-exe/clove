import SwiftUI

struct LibraryRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(UpdateService.self) private var updates
    @Environment(\.openWindow) private var openWindow
    @State private var isShowingOnboarding = false
    @State private var whatsNewRelease: WhatsNewRelease?
    @State private var offeredUpdate: UpdateManifest?

    var body: some View {
        @Bindable var model = model

        librarySplit
            .frame(minWidth: Metrics.windowMinWidth, minHeight: Metrics.windowMinHeight)
            .background(LibraryWindowAccessor())
            .task {
                await model.startIfNeeded()
                await updates.checkForUpdates()
                presentInitialSheets()
            }
            .onAppear {
                WindowBridge.shared.openLibraryWindow = {
                    openWindow(id: CloveWindowID.library)
                }
                LibraryWindowTracker.shared.registerOpenWindow {
                    openWindow(id: CloveWindowID.library)
                }
            }
            .onChange(of: updates.availableUpdate) {
                if offeredUpdate == nil {
                    offeredUpdate = updates.availableUpdate
                }
            }
            .sheet(isPresented: $model.isShowingSkillBuilder) {
                NewSkillSheet()
                    .environment(model)
            }
            .sheet(isPresented: $isShowingOnboarding) {
                OnboardingFlow()
                    .environment(model)
                    .interactiveDismissDisabled()
            }
            .sheet(item: $whatsNewRelease) { release in
                WhatsNewSheet(release: release) {
                    model.settings.lastSeenWhatsNewVersion = release.version
                }
            }
            .sheet(item: $offeredUpdate, onDismiss: skipUpdateIfStillPending) { update in
                UpdateAvailableSheet(update: update)
                    .environment(updates)
            }
    }

    /// One three-column layout for every section, so switching sections never
    /// rebuilds the sidebar.
    private var columns: some View {
        NavigationSplitView {
            LibrarySidebar()
        } content: {
            // Widths live on the column, not on each list: set inside a
            // switch they were ignored and the column stayed narrow.
            Group {
                switch model.section {
                case .home:
                    HomeList()
                case .library:
                    LibraryList()
                case .discover:
                    DiscoverList()
                case .cleanup:
                    CleanupList()
                case .resources(let kind):
                    ResourceList(kind: kind)
                case .secrets:
                    SecretsList()
                case .running:
                    RunningList()
                }
            }
            .navigationSplitViewColumnWidth(min: Metrics.listMinWidth, ideal: Metrics.listIdealWidth, max: 480)
        } detail: {
            Group {
                switch model.section {
                case .home:
                    HomeDetail()
                case .library:
                    LibraryDetail()
                case .discover:
                    DiscoverDetail()
                case .cleanup:
                    CleanupSummary()
                case .resources:
                    ResourceDetailColumn()
                case .secrets:
                    SecretDetail()
                case .running:
                    RunningDetail()
                }
            }
            .navigationSplitViewColumnWidth(min: Metrics.detailMinWidth, ideal: 560)
        }
    }

    private var librarySplit: some View {
        columns
        .navigationTitle("Clove")
        .navigationSubtitle(subtitle)
        .alert(
            model.manager.failure?.title ?? "",
            isPresented: isShowingFailure,
            presenting: model.manager.failure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
        .confirmationDialog(
            "Replace the existing skill?",
            isPresented: isShowingConflict,
            titleVisibility: .visible,
            presenting: model.manager.pendingConflict
        ) { pending in
            Button("Replace “\(pending.skill.skillId)”", role: .destructive, action: replaceConflict)
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text("A skill named “\(pending.skill.skillId)” that didn't come from \(pending.skill.source) is already in ~/.agents/skills. It will be moved to the Trash.")
        }
    }

    private var isShowingFailure: Binding<Bool> {
        Binding {
            model.manager.failure != nil
        } set: { isShowing in
            if !isShowing { model.manager.failure = nil }
        }
    }

    private var isShowingConflict: Binding<Bool> {
        Binding {
            model.manager.pendingConflict != nil
        } set: { isShowing in
            if !isShowing { model.manager.pendingConflict = nil }
        }
    }

    private func replaceConflict() {
        Task { await model.manager.confirmPendingConflict() }
    }

    private func skipUpdateIfStillPending() {
        guard let update = updates.availableUpdate else { return }
        updates.dismiss(update)
    }

    private var subtitle: String {
        guard model.settings.hasCompletedOnboarding else { return "Finish setup to scan" }
        if model.isScanning && model.skills.isEmpty {
            return "Scanning"
        }
        switch model.section {
        case .home: return "Everything your agents load"
        case .running: return "Live agents and servers"
        case .discover: return "Skills from skills.sh"
        case .cleanup: return "Free up context and disk space"
        case .resources(let kind): return kind.subtitle
        case .secrets: return "API keys, kept in your Keychain"
        case .library: break
        }
        guard model.didScan else { return "" }
        let count = model.catalog.count
        return count == 1 ? "1 skill on this Mac" : "\(count) skills on this Mac"
    }

    private func presentInitialSheets() {
        if !model.settings.hasCompletedOnboarding {
            isShowingOnboarding = true
            return
        }
        if let update = updates.availableUpdate {
            offeredUpdate = update
            return
        }
        whatsNewRelease = WhatsNewCatalog.unseenRelease(
            lastSeenVersion: model.settings.lastSeenWhatsNewVersion
        )
    }
}

#Preview {
    LibraryRootView()
        .environment(AppModel.preview)
        .environment(UpdateService(settings: AppModel.preview.settings))
}
