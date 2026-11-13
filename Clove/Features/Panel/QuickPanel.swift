import SwiftUI

/// The menu bar panel: whichever block is picked fills it, and the block bar
/// along the bottom switches between the ones in your set.
struct QuickPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let settings = model.settings
        // Always a block from the set, even if settings were edited elsewhere.
        let block = settings.panelBlocks.contains(settings.panelBlock) ? settings.panelBlock : (settings.panelBlocks.first ?? .skills)

        VStack(spacing: 0) {
            Group {
                if model.isPanelVisible {
                    switch block {
                    case .skills: SkillsPanel()
                    case .storage: StorageBlock()
                    case .running: RunningBlock()
                    case .cleanup: CleanupBlock()
                    case .trending: TrendingBlock()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .id(block)

            Divider()
                .opacity(0.6)

            PanelBlockBar()
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: block)
        .frame(
            minWidth: Metrics.panelMinWidth,
            idealWidth: Metrics.panelWidth,
            maxWidth: Metrics.panelMaxWidth,
            minHeight: Metrics.panelMinHeight,
            idealHeight: Metrics.panelHeight,
            maxHeight: Metrics.panelMaxHeight
        )
    }
}

// MARK: - Block bar

/// The blocks in your set, as tiles. The picked one opens out to show its
/// name; the last tile adds or removes blocks.
struct PanelBlockBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let settings = model.settings
        let current = settings.panelBlocks.contains(settings.panelBlock) ? settings.panelBlock : settings.panelBlocks.first

        HStack(spacing: 4) {
            ForEach(Array(settings.panelBlocks.enumerated()), id: \.element) { index, block in
                PanelBlockTile(block: block, isPicked: current == block) {
                    settings.panelBlock = block
                }
                .help("\(block.title) (⌘\(index + 1))")
            }

            Spacer(minLength: 4)

            Menu {
                Section("Blocks in the Panel") {
                    ForEach(PanelBlock.allCases) { block in
                        Toggle(isOn: membership(block)) {
                            Label(block.title, systemImage: block.symbol)
                            Text(block.detail)
                        }
                        // One block always stays, or the panel would be empty.
                        .disabled(settings.panelBlocks == [block])
                    }
                }
                Divider()
                Button("Reset to Default Blocks") {
                    settings.panelBlocks = PanelBlock.defaults
                    if !PanelBlock.defaults.contains(settings.panelBlock) { settings.panelBlock = .skills }
                }
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
            .help("Choose the blocks in this panel")
            .accessibilityLabel("Choose blocks")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .animation(.spring(duration: 0.28, bounce: 0.12), value: settings.panelBlock)
        .animation(.spring(duration: 0.28, bounce: 0.12), value: settings.panelBlocks)
    }

    private func membership(_ block: PanelBlock) -> Binding<Bool> {
        model.settings.blockBinding(block)
    }
}

/// One block's tile: its icon in its colour, and its name once picked.
private struct PanelBlockTile: View {
    let block: PanelBlock
    let isPicked: Bool
    let pick: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: pick) {
            HStack(spacing: 6) {
                Image(systemName: block.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isPicked ? block.tint : Color.secondary)
                    .frame(width: 16)
                if isPicked {
                    Text(block.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                }
            }
            .padding(.horizontal, isPicked ? 10 : 7)
            .frame(height: 28)
            .background(background, in: .rect(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isPicked ? block.tint.opacity(0.35) : .clear, lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(PanelTilePressStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityLabel(block.title)
        .accessibilityAddTraits(isPicked ? [.isSelected] : [])
    }

    private var background: Color {
        if isPicked { return block.tint.opacity(0.16) }
        return isHovered ? Color.primary.opacity(0.07) : .clear
    }
}

private struct PanelTilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Shared block chrome

/// A block's title row: what it is, a count, and a way into the full section.
struct PanelBlockHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel
    let block: PanelBlock
    var note: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(block.title)
                .font(.system(size: 13, weight: .semibold))
            if let note {
                Text(note)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                openInClove(model, block.destination, closePanel: closePanel)
            } label: {
                HStack(spacing: 3) {
                    Text("Open in Clove")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Color.primary.opacity(0.06), in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(PanelTilePressStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

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

// MARK: - Blocks

/// The storage instrument, live, at panel width.
struct StorageBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel

    var body: some View {
        let storage = model.storage

        VStack(spacing: 0) {
            PanelBlockHeader(block: .storage, note: storage.volume.map { "\(StorageFormat.gb($0.available)) free" })

            StorageCard(store: storage, pinned: nil, isCompact: true, openClear: { clean in
                openInClove(model, .storage, closePanel: closePanel) {
                    storage.pendingClean = clean
                }
            })
            .padding(.horizontal, 10)

            let largest = storage.largest(limit: 6)
            if !largest.isEmpty {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(largest) { item in
                            PanelBlockRow {
                                storage.reveal(item)
                            } content: {
                                HStack(spacing: 8) {
                                    StorageGlyph(symbol: item.kind.symbol, size: 13)
                                        .foregroundStyle(item.kind.paperTint)
                                    Text(item.name)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(StorageFormat.gb(item.bytes))
                                        .font(.system(size: 11).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .help("Show \(item.name) in Finder")
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.never)
            } else {
                Spacer(minLength: 10)
            }
        }
        .task {
            await storage.scanIfNeeded()
        }
    }
}

struct RunningBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel

    var body: some View {
        let running = model.running
        let processes = RunningProcess.Kind.allCases.flatMap { running.items(of: $0) }

        VStack(spacing: 0) {
            PanelBlockHeader(block: .running, note: processes.count.formatted())

            if processes.isEmpty {
                PanelBlockEmpty(symbol: "waveform.path.ecg", text: "Nothing running. Agent sessions and their servers show up here.")
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(processes) { process in
                            PanelBlockRow {
                                openInClove(model, .running, closePanel: closePanel) {
                                    model.running.selection = process.id
                                }
                            } content: {
                                RunningRow(process: process, isStopping: running.stopping.contains(process.pid))
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
            await running.refresh(known: model.knownServers)
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
            PanelBlockHeader(block: .cleanup, note: candidates.isEmpty ? nil : "\(candidates.count) unused")

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
            PanelBlockHeader(block: .trending, note: "skills.sh")

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
