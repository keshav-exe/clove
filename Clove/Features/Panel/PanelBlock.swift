import SwiftUI

/// A tab in the notch. You pick which ones are in your set; their icons sit
/// beside the notch and switch between them.
enum PanelBlock: String, CaseIterable, Identifiable, Sendable {
    case now
    case skills
    case storage
    case trending

    var id: String { rawValue }

    /// Skill cleanup lives with the skills in Clove's window: it's a once-a-month
    /// tidy, not something to reach for from the notch.
    static let defaults: [PanelBlock] = [.now, .skills, .storage]
    /// Lists you scroll get the island's full height; the rest size to fit,
    /// so there's never empty island below them or content cut off.
    var fitsContent: Bool {
        switch self {
        case .now, .storage: true
        case .skills, .trending: false
        }
    }

    /// The strip beside the notch has room for this many tabs.
    static let maxTabs = 4

    var title: String {
        switch self {
        case .now: "Now"
        case .skills: "Skills"
        case .storage: "Storage"
        case .trending: "Trending"
        }
    }

    var detail: String {
        switch self {
        case .now: "Agents at work, servers up, and what's busy"
        case .skills: "Search, copy, and insert skills"
        case .storage: "The disk, live, and what to clear"
        case .trending: "What's climbing on skills.sh"
        }
    }

    var symbol: String {
        switch self {
        case .now: "dot.radiowaves.left.and.right"
        case .skills: "square.stack.3d.up.fill"
        case .storage: "internaldrive.fill"
        case .trending: "chart.line.uptrend.xyaxis"
        }
    }

    /// Each block's colour, from the same vivid set the storage bar uses.
    var tint: Color {
        switch self {
        case .now: Palette.Vivid.violet
        case .skills: Palette.Vivid.blue
        case .storage: Palette.Vivid.orange
        case .trending: Palette.Vivid.pink
        }
    }

    /// Where "Open in Clove" goes.
    var destination: SidebarItem {
        switch self {
        case .now: .running
        case .skills: .library(.all)
        case .storage: .storage
        case .trending: .discover
        }
    }
}

extension SettingsStore {
    /// The tab showing, always one from your set.
    var currentTab: PanelBlock {
        panelBlocks.contains(panelBlock) ? panelBlock : (panelBlocks.first ?? .skills)
    }

    /// Adds or removes a block. One always stays, or the panel would be empty.
    /// A block added goes on the end; Settings reorders them by dragging.
    func setBlock(_ block: PanelBlock, included: Bool) {
        if included {
            guard panelBlocks.count < PanelBlock.maxTabs, !panelBlocks.contains(block) else { return }
            panelBlocks.append(block)
        } else {
            guard panelBlocks != [block] else { return }
            panelBlocks.removeAll { $0 == block }
            if panelBlock == block, let first = panelBlocks.first {
                panelBlock = first
            }
        }
    }

    /// Every block in Settings' order: yours first, then the rest.
    var blockOrderBinding: Binding<[PanelBlock]> {
        Binding {
            self.panelBlocks + PanelBlock.allCases.filter { !self.panelBlocks.contains($0) }
        } set: { order in
            self.panelBlocks = order.filter { self.panelBlocks.contains($0) }
        }
    }

    func blockBinding(_ block: PanelBlock) -> Binding<Bool> {
        Binding {
            self.panelBlocks.contains(block)
        } set: { included in
            self.setBlock(block, included: included)
        }
    }
}
