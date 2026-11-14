import SwiftUI

struct LibraryRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var whatsNewRelease: WhatsNewRelease?

    var body: some View {
        Group {
            if isReady {
                unlocked
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: isReady)
        .frame(minWidth: Metrics.windowMinWidth, minHeight: Metrics.windowMinHeight)
        .background(LibraryWindowAccessor())
        .onAppear {
            WindowBridge.shared.openLibraryWindow = {
                openWindow(id: CloveWindowID.library)
            }
            LibraryWindowTracker.shared.registerOpenWindow {
                openWindow(id: CloveWindowID.library)
            }
        }
        .task {
            await model.license.revalidateIfDue()
        }
    }

    /// Setup is done and this Mac has a license. Until then the window shows
    /// the guide, or just its license step for a Mac set up before.
    private var isReady: Bool {
        model.license.isUnlocked && model.settings.hasCompletedOnboarding
    }

    private var unlocked: some View {
        @Bindable var model = model

        return librarySplit
            .task {
                await model.startIfNeeded()
                presentInitialSheets()
            }
            .sheet(isPresented: $model.isShowingSkillBuilder) {
                NewSkillSheet()
                    .environment(model)
            }
            .sheet(item: $whatsNewRelease) { release in
                WhatsNewSheet(release: release) {
                    model.settings.lastSeenWhatsNewVersion = release.version
                }
            }
    }

    /// Sidebar and one page. Each section draws its own page; lists open what
    /// you pick in an inspector instead of a third column.
    private var columns: some View {
        NavigationSplitView {
            LibrarySidebar()
        } detail: {
            SectionPage()
                .frame(minWidth: Metrics.pageMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.background)
        }
    }

    private var librarySplit: some View {
        columns
        .navigationTitle("Clove")
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

    private func presentInitialSheets() {
        whatsNewRelease = WhatsNewCatalog.unseenRelease(
            lastSeenVersion: model.settings.lastSeenWhatsNewVersion
        )
    }
}

#Preview {
    LibraryRootView()
        .environment(AppModel.preview)
        .environment(UpdateService())
}
