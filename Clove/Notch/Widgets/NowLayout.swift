import SwiftUI

/// A section of the Now board. You choose which show, and in what order.
enum NowSection: String, CaseIterable, Identifiable, Sendable {
    case agents
    case ports
    case limits
    case busy
    case elsewhere

    var id: String { rawValue }

    static let defaults: [NowSection] = [.agents, .ports, .limits, .busy, .elsewhere]

    var title: String {
        switch self {
        case .agents: "Agents at work"
        case .ports: "Servers and ports"
        case .limits: "Plan limits"
        case .busy: "Busy apps"
        case .elsewhere: "MCP servers and containers"
        }
    }

    var symbol: String {
        switch self {
        case .agents: "sparkles"
        case .ports: "network"
        case .limits: "gauge.with.dots.needle.67percent"
        case .busy: "flame"
        case .elsewhere: "server.rack"
        }
    }
}

extension SettingsStore {
    /// Moves a section one place up (-1) or down (+1).
    func moveSection(_ section: NowSection, by offset: Int) {
        guard let index = nowSections.firstIndex(of: section) else { return }
        let target = index + offset
        guard nowSections.indices.contains(target) else { return }
        nowSections.swapAt(index, target)
    }

    func setSection(_ section: NowSection, shown: Bool) {
        if shown {
            guard !nowSections.contains(section) else { return }
            // Comes back where it sits in the catalogue, among those shown.
            let order = NowSection.allCases
            let position = nowSections.firstIndex { order.firstIndex(of: $0)! > order.firstIndex(of: section)! } ?? nowSections.endIndex
            nowSections.insert(section, at: position)
        } else {
            nowSections.removeAll { $0 == section }
        }
    }

    func sectionBinding(_ section: NowSection) -> Binding<Bool> {
        Binding { self.nowSections.contains(section) } set: { self.setSection(section, shown: $0) }
    }
}
