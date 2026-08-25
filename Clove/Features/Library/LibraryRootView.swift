import SwiftUI

struct LibraryRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(UpdateService.self) private var updates
    @Environment(LicenseService.self) private var license
    @Environment(\.openWindow) private var openWindow
    @State private var isShowingOnboarding = false
    @State private var whatsNewRelease: WhatsNewRelease?
    @State private var offeredUpdate: UpdateManifest?

    var body: some View {
        Group {
            if license.isUnlocked {
                librarySplit
            } else {
                LicenseActivationView()
            }
        }
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
            guard license.isUnlocked else { return }
            if offeredUpdate == nil {
                offeredUpdate = updates.availableUpdate
            }
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
        .onChange(of: license.isUnlocked) {
            presentInitialSheets()
        }
    }

    private var librarySplit: some View {
        NavigationSplitView {
            LibrarySidebar()
        } content: {
            LibraryList()
        } detail: {
            LibraryDetail()
        }
        .navigationTitle("Clove")
        .navigationSubtitle(subtitle)
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
        guard model.didScan else { return "" }
        let count = model.catalog.count
        return count == 1 ? "1 skill on this Mac" : "\(count) skills on this Mac"
    }

    private func presentInitialSheets() {
        guard license.isUnlocked else { return }
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
        .environment(LicenseService.shared)
}
