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
        case .cleanup: CleanupBlock()
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

struct CleanupBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel

    var body: some View {
        let candidates = model.cleanupCandidates
        let tokens = candidates.reduce(0) { $0 + $1.tokens }
        let leftovers = (model.cleanup.leftovers.value ?? []).filter(\.isOutdated).reduce(Int64(0)) { $0 + $1.bytes }

        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(tokens, format: .number)
                    .font(.system(size: 40, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText(value: Double(tokens)))
                Text(candidates.isEmpty ? "Every skill and command was used recently." : "tokens every session spends listing skills and commands nobody has called lately")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)

            VStack(spacing: 1) {
                ForEach(Array(candidates.sorted { $0.tokens > $1.tokens }.prefix(4))) { candidate in
                    PanelBlockRow {
                        openInClove(model, .cleanup, closePanel: closePanel)
                    } content: {
                        HStack {
                            Text(candidate.displayName)
                                .font(.system(size: 12.5, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text("\(candidate.tokens.formatted()) tokens")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if leftovers > 0 {
                    PanelBlockRow {
                        openInClove(model, .cleanup, closePanel: closePanel)
                    } content: {
                        HStack {
                            Label("Agent leftovers", systemImage: "shippingbox")
                                .font(.system(size: 12.5, weight: .medium))
                            Spacer(minLength: 8)
                            Text(leftovers.formatted(.byteCount(style: .file)))
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)

            Spacer(minLength: 8)

            if !candidates.isEmpty {
                Button {
                    openInClove(model, .cleanup, closePanel: closePanel)
                } label: {
                    Text("Review \(candidates.count) in Clove")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .task {
            await model.cleanup.scanIfNeeded()
        }
        .task {
            await model.cleanup.scanLeftovers()
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
