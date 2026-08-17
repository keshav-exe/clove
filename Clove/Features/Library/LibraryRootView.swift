import SwiftUI

struct LibraryRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var isShowingOnboarding = false

    var body: some View {
        NavigationSplitView {
            LibrarySidebar()
        } content: {
            LibraryList()
        } detail: {
            LibraryDetail()
        }
        .navigationTitle("Clove")
        .navigationSubtitle(subtitle)
        .frame(minWidth: Metrics.windowMinWidth, minHeight: Metrics.windowMinHeight)
        .task {
            await model.startIfNeeded()
        }
        .onAppear {
            WindowBridge.shared.openLibraryWindow = {
                openWindow(id: CloveWindowID.library)
            }
            isShowingOnboarding = !model.settings.hasCompletedOnboarding
        }
        .sheet(isPresented: $isShowingOnboarding) {
            OnboardingFlow()
                .environment(model)
                .interactiveDismissDisabled()
        }
    }

    private var subtitle: String {
        guard model.settings.hasCompletedOnboarding else { return "Finish setup to scan" }
        if model.isScanning && model.skills.isEmpty {
            return "Scanning"
        }
        guard model.didScan else { return "" }
        let count = model.skills.count
        return count == 1 ? "1 skill on this Mac" : "\(count) skills on this Mac"
    }
}

#Preview {
    LibraryRootView()
        .environment(AppModel.preview)
}
