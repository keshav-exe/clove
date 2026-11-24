import SwiftUI

/// The tabs inside the notch, one view per tab. The island draws the tab
/// strip and the title; these are only the content beneath it.
struct PanelBlockContent: View {
    let block: PanelBlock

    var body: some View {
        switch block {
        case .now: NowTab()
        case .skills: SkillsPanel()
        case .storage: StorageBlock()
        case .trending: TrendingBlock()
        }
    }
}

// MARK: - Shared

/// Opens the main window on a section, and gets the panel out of the way.
@MainActor
func openInClove(_ model: AppModel, _ destination: SidebarItem, closePanel: ClosePanelAction, then: (@MainActor @Sendable () -> Void)? = nil) {
    closePanel()
    NSApp.activate()
    WindowBridge.shared.showLibraryWindow()
    model.show(destination)
    if let then {
        // The section's page has to be on screen before it can show a sheet or a selection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: then)
    }
}

/// A row in a block: the same hover fill as the window's list pages.
struct PanelBlockRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isHovered ? Color.primary.opacity(0.07) : .clear, in: .rect(cornerRadius: 8, style: .continuous))
                .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Tabs

/// What's live, sized to fit: the island grows to the board's height.
struct NowTab: View {
    @Environment(AppModel.self) private var model
    @Environment(NotchModel.self) private var notch

    var body: some View {
        ScrollView {
            NowBoard()
                .padding(.top, 4)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { notch.measuredHeights[.now] = $0 }
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        // A board taller than the island fades out under its edge, not sliced mid-line.
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .task {
            await model.containers.refresh()
        }
    }
}

/// The storage instrument, live, at panel width.
struct StorageBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel

    var body: some View {
        let storage = model.storage

        VStack(spacing: 0) {
            Color.clear.frame(height: 6)

            StorageCard(store: storage, pinned: nil, isCompact: true, openClear: { clean in
                openInClove(model, .storage, closePanel: closePanel) {
                    storage.pendingClean = clean
                }
            })
            .padding(.horizontal, 10)
        }
        .padding(.bottom, 10)
        .task {
            await storage.scanIfNeeded()
        }
    }
}

struct TrendingBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel

    var body: some View {
        let skills = model.marketplace.feeds[.trending]?.value ?? []

        VStack(spacing: 0) {
            Color.clear.frame(height: 6)

            if skills.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(skills.prefix(12).enumerated()), id: \.element.id) { index, skill in
                            PanelBlockRow {
                                openInClove(model, .discover, closePanel: closePanel) {
                                    model.marketplace.feed = .trending
                                    model.marketplace.selection = skill.id
                                }
                            } content: {
                                DiscoverRow(skill: skill, rank: index + 1, showsChange: false, isInstalled: model.isInstalled(skill))
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.never)
            }
        }
        .task {
            await model.marketplace.loadFeed(.trending)
        }
    }
}

/// An empty block: what will show up here, sized to fill it.
struct PanelBlockEmpty: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
