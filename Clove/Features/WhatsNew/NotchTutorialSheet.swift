import SwiftUI

/// What's New for the notch: four short pages, each with the notch doing the
/// thing it describes, then the choice of where Clove lives.
struct NotchTutorialSheet: View {
    var onFinish: () -> Void

    @Environment(AppModel.self) private var model
    @State private var page = 0
    @State private var neighbors: [NotchNeighbor] = []

    private struct Page {
        let scene: NotchDemo.Scene
        let title: String
        let subtitle: String
    }

    private var shortcut: String {
        guard model.settings.hotKeyEnabled, let chord = model.settings.hotKey else { return "the shortcut" }
        return chord.displayString
    }

    private var place: String {
        NotchGeometry.hasHardwareNotch ? "notch" : "top of the screen"
    }

    private var pages: [Page] {
        [
            Page(scene: .peek, title: "Clove Moved into the \(place.capitalized)", subtitle: "Hover the \(place) to peek at your agents, servers and storage. Move away and it closes."),
            Page(scene: .search, title: "Click to Search", subtitle: "Click the \(place), or press \(shortcut), and it opens on search. Esc, or a click anywhere else, puts it away."),
            Page(scene: .working, title: "Agents at Work", subtitle: "While an agent works, the \(place) shows the app it's working in. With nothing going on, it stays out of sight."),
            Page(scene: .done, title: "Done, and It Tells You", subtitle: "When an agent finishes, the \(place) says so for a moment. Show takes you back to it."),
        ]
    }

    private var count: Int { pages.count + 1 }
    private var isChoice: Bool { page == pages.count }

    var body: some View {
        FeatureSheet(
            title: isChoice ? "Notch or Menu Bar?" : pages[page].title,
            subtitle: isChoice ? "Pick where Clove lives. Settings, General switches it any time." : pages[page].subtitle,
            pageIndex: page,
            pageCount: count,
            continueTitle: isChoice ? "Done" : "Continue",
            showsBack: page > 0,
            onBack: { withAnimation(.easeOut(duration: 0.2)) { page -= 1 } },
            onContinue: advance
        ) {
            // Always a view, so the sheet lays out the same on every page.
            if isChoice {
                choice
            } else {
                Color.clear
            }
        } hero: {
            NotchDemo(
                scene: isChoice ? (model.settings.accessMode == .notch ? .peek : .menuBar) : pages[page].scene,
                size: CGSize(width: 440, height: isChoice ? 200 : 300)
            )
            .id(isChoice ? "choice-\(model.settings.accessMode.rawValue)" : "page-\(page)")
            .transition(.opacity)
            .padding(.top, 24)
        }
        .animation(.easeOut(duration: 0.2), value: page)
        .task {
            neighbors = await Task.detached { NotchNeighbors.installed() }.value
        }
    }

    private var choice: some View {
        @Bindable var settings = model.settings
        let rivals = neighbors.filter { !$0.playsAlong }

        return VStack(alignment: .leading, spacing: 10) {
            ModeCard(
                mode: .notch,
                symbol: "rectangle.topthird.inset.filled",
                detail: "Peeks on hover, and tells you when agents finish.",
                isPicked: settings.accessMode == .notch,
                isSuggested: rivals.isEmpty
            ) { settings.accessMode = .notch }
            ModeCard(
                mode: .menuBar,
                symbol: "menubar.rectangle",
                detail: "The icon and panel you had before. Leaves the notch free.",
                isPicked: settings.accessMode == .menuBar,
                isSuggested: !rivals.isEmpty
            ) { settings.accessMode = .menuBar }
            if !rivals.isEmpty {
                Text("\(NotchNeighbors.list(rivals)) also \(rivals.count == 1 ? "uses" : "use") the notch, so Clove stayed in the menu bar for now.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    private func advance() {
        if isChoice {
            onFinish()
        } else {
            withAnimation(.easeOut(duration: 0.2)) { page += 1 }
        }
    }
}
