import AppKit
import Observation
import SwiftUI

/// Something worth a moment of your attention, shown by the notch briefly
/// growing to say it, then getting out of the way.
struct NotchMoment: Identifiable, Equatable {
    enum Tone: Equatable {
        case done
        case neutral
        case warning
    }

    struct Action: Equatable {
        let title: String
        let perform: @MainActor () -> Void

        static func == (lhs: Action, rhs: Action) -> Bool { lhs.title == rhs.title }
    }

    let id = UUID()
    let symbol: String
    let tone: Tone
    let title: String
    let detail: String?
    var action: Action?
    var duration: Duration = .seconds(5)
    /// An agent's task starting or ending: shown as its card, glowing in its app's colours.
    var session: AgentSession? = nil
}

/// The island's state: how open it is and what it's showing.
@MainActor
@Observable
final class NotchModel {
    enum Phase: Equatable {
        /// Just the notch, with a quiet ear when an agent is at work.
        case collapsed
        /// Open on a tab. Hovering opens it without focus; a click or the
        /// shortcut focuses it so you can type.
        case open
        /// A moment is being announced.
        case moment
    }

    var phase: Phase = .collapsed
    /// Another app's island has the notch: the ears fold away and moments
    /// wait in line until it's released.
    var isYielding = false
    /// Open and holding the keyboard. Unfocused, it closes when the pointer
    /// leaves; focused, it waits for Esc, the shortcut, or a click elsewhere.
    var isFocused = false
    var geometry: NotchGeometry?
    private(set) var moment: NotchMoment?
    /// Content heights of the tabs that size to fit, as last measured. Kept
    /// across launches, so the first open already knows its height and the
    /// island doesn't retarget mid-spring.
    var measuredHeights: [PanelBlock: CGFloat] = NotchModel.savedHeights() {
        didSet {
            guard measuredHeights != oldValue else { return }
            let raw = Dictionary(uniqueKeysWithValues: measuredHeights.map { ($0.key.rawValue, Double($0.value)) })
            UserDefaults.standard.set(raw, forKey: Self.heightsKey)
        }
    }

    private static let heightsKey = "notchTabHeights"

    private static func savedHeights() -> [PanelBlock: CGFloat] {
        let raw = UserDefaults.standard.dictionary(forKey: heightsKey) as? [String: Double] ?? [:]
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in PanelBlock(rawValue: key).map { ($0, CGFloat(value)) } })
    }
    /// Set while the pointer is over a moment, which holds it on screen.
    var isHoveringMoment = false {
        didSet { if !isHoveringMoment, phase == .moment { scheduleMomentEnd() } }
    }

    let agents: AgentActivityStore
    let settings: SettingsStore

    @ObservationIgnored private var queue: [NotchMoment] = []
    @ObservationIgnored private var momentTask: Task<Void, Never>?

    init(agents: AgentActivityStore, settings: SettingsStore) {
        self.agents = agents
        self.settings = settings
    }

    var tab: PanelBlock { settings.currentTab }

    var isExpanded: Bool {
        phase != .collapsed
    }

    var isHardware: Bool {
        geometry?.isHardware ?? true
    }

    // MARK: - Size

    static let panelWidth: CGFloat = 440
    static let momentWidth: CGFloat = 400
    static let shoulder: CGFloat = 10
    /// The tallest a tab gets; Now fits its content up to this.
    static let contentHeight: CGFloat = 380

    var notchSize: CGSize {
        geometry?.size ?? CGSize(width: 190, height: 32)
    }

    /// Something is going on: the island shows it beside the notch. Otherwise
    /// it stays hidden inside the notch.
    var isLive: Bool { !isYielding && !agents.working.isEmpty }

    /// Each ear holds one app icon, with room to breathe on both sides, and
    /// widens for a fanned stack when agents work in several apps.
    static let earWidth: CGFloat = 34
    static let earIconSize: CGFloat = 18

    var earWidth: CGFloat {
        let apps = min(AgentIcons.distinct(agents.working).count, 3)
        return max(Self.earWidth, AgentIconStack.width(count: apps, size: Self.earIconSize) + 16)
    }

    /// The island's outer size for the current phase, shoulders included.
    var size: CGSize {
        let notch = notchSize
        let body: CGSize
        switch phase {
        case .collapsed:
            // Tucked just inside the hardware notch, so nothing shows around
            // it; it's only where the island grows from. The stand-in on
            // screens without a notch is the notch's own size, since it's all there is.
            if isLive {
                body = CGSize(width: notch.width + earWidth * 2, height: notch.height)
            } else if isHardware {
                return CGSize(width: notch.width - 4, height: notch.height - 2)
            } else {
                body = notch
            }
        case .moment:
            // An agent's card is a touch taller, so its glow has room to breathe.
            let tall = moment?.session != nil
            body = CGSize(width: max(Self.momentWidth, notch.width + 120), height: notch.height + (tall ? 62 : 58))
        case .open:
            let content = tab.fitsContent ? min(max(measuredHeights[tab] ?? 160, 72), Self.contentHeight) : Self.contentHeight
            body = CGSize(width: Self.panelWidth, height: notch.height + content)
        }
        return CGSize(width: body.width + shoulderRadius * 2, height: body.height)
    }

    var shoulderRadius: CGFloat {
        guard phase == .collapsed else { return Self.shoulder }
        return isHardware && !isLive ? 0 : 6
    }

    var bottomRadius: CGFloat {
        switch phase {
        // Rounder than the notch's own corners, so it stays inside them.
        case .collapsed: isHardware ? 12 : notchSize.height / 2
        case .moment: 22
        default: 26
        }
    }

    // MARK: - Moments

    func present(_ moment: NotchMoment) {
        // Moments are the notch's alone; the menu bar has no room for them.
        guard settings.accessMode == .notch else { return }
        if isYielding {
            if queue.count < 3 { queue.append(moment) }
            return
        }
        // Open or being looked at: the board already shows it.
        switch phase {
        case .open:
            return
        case .collapsed, .moment:
            break
        }
        if self.moment == nil {
            show(moment)
        } else if queue.count < 3 {
            queue.append(moment)
        }
    }

    private func show(_ next: NotchMoment) {
        moment = next
        phase = .moment
        scheduleMomentEnd()
    }

    private func scheduleMomentEnd() {
        momentTask?.cancel()
        guard let duration = moment?.duration else { return }
        momentTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.advanceMoments()
        }
    }

    func advanceMoments() {
        guard !isHoveringMoment else { return }
        momentTask?.cancel()
        if queue.isEmpty {
            moment = nil
            if phase == .moment { phase = .collapsed }
        } else {
            show(queue.removeFirst())
        }
    }

    /// Shows what queued up while another app had the notch.
    func resumeMoments() {
        guard !isYielding, moment == nil, phase == .collapsed, !queue.isEmpty else { return }
        show(queue.removeFirst())
    }

    /// Opening the island answers whatever was being announced.
    func clearMoments() {
        momentTask?.cancel()
        queue.removeAll()
        moment = nil
        isHoveringMoment = false
    }
}
