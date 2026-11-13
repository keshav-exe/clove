import SwiftUI

/// A piece of Clove that can sit in the menu bar panel. You pick which ones
/// are in your set; their tiles sit along the bottom and switch the panel.
enum PanelBlock: String, CaseIterable, Identifiable, Sendable {
    case skills
    case storage
    case running
    case cleanup
    case trending

    var id: String { rawValue }

    static let defaults: [PanelBlock] = [.skills, .storage, .running, .cleanup]

    var title: String {
        switch self {
        case .skills: "Skills"
        case .storage: "Storage"
        case .running: "Running"
        case .cleanup: "Cleanup"
        case .trending: "Trending"
        }
    }

    var detail: String {
        switch self {
        case .skills: "Search, copy, and insert skills"
        case .storage: "The disk, live, and what to clear"
        case .running: "Agent sessions and servers"
        case .cleanup: "Context spent on unused skills"
        case .trending: "What's climbing on skills.sh"
        }
    }

    var symbol: String {
        switch self {
        case .skills: "square.stack.3d.up.fill"
        case .storage: "internaldrive.fill"
        case .running: "waveform.path.ecg"
        case .cleanup: "leaf.fill"
        case .trending: "chart.line.uptrend.xyaxis"
        }
    }

    /// Each block's colour, from the same vivid set the storage bar uses.
    var tint: Color {
        switch self {
        case .skills: Palette.Vivid.blue
        case .storage: Palette.Vivid.orange
        case .running: Palette.mint
        case .cleanup: Palette.Vivid.green
        case .trending: Palette.Vivid.pink
        }
    }

    /// Where "Open in Clove" goes.
    var destination: SidebarItem {
        switch self {
        case .skills: .library(.all)
        case .storage: .storage
        case .running: .running
        case .cleanup: .cleanup
        case .trending: .discover
        }
    }
}

extension SettingsStore {
    /// Adds or removes a block. One always stays, or the panel would be empty,
    /// and blocks keep the catalogue's order however they were added.
    func setBlock(_ block: PanelBlock, included: Bool) {
        if included {
            panelBlocks = PanelBlock.allCases.filter { panelBlocks.contains($0) || $0 == block }
        } else {
            guard panelBlocks != [block] else { return }
            panelBlocks.removeAll { $0 == block }
            if panelBlock == block, let first = panelBlocks.first {
                panelBlock = first
            }
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
