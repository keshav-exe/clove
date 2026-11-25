import SwiftUI

/// What the island's controls ask of the window around it.
struct NotchActions {
    var open: (PanelBlock?) -> Void = { _ in }
    var close: () -> Void = {}
    var showMenu: () -> Void = {}
}

extension EnvironmentValues {
    @Entry var notchActions = NotchActions()
}

/// The island, hanging from the top of a canvas the size of its largest state.
struct NotchView: View {
    @Environment(AppModel.self) private var model
    @Environment(NotchModel.self) private var notch
    @Environment(\.notchActions) private var actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = notch.size

        let hidden = notch.isHiddenAtRest
        island
            .frame(width: size.width, height: size.height, alignment: .top)
            // A floating island at rest has nothing to show: it waits out of sight.
            .opacity(hidden ? 0 : 1)
            .scaleEffect(hidden ? 0.82 : 1, anchor: .top)
            .padding(.top, notch.geometry?.topInset ?? 0)
            .frame(width: NotchGeometry.canvas.width, height: NotchGeometry.canvas.height, alignment: .top)
            .animation(motion, value: notch.phase)
            .animation(motion, value: size)
            .animation(motion, value: hidden)
            .preferredColorScheme(.dark)
    }

    /// The island is a physical thing, so it moves on springs, which also
    /// carry their speed through when you change your mind halfway. Growing
    /// has a touch of give, the way the Dynamic Island settles; shrinking is
    /// quicker and lands without overshoot, since it's only getting out of the
    /// way. With Reduce Motion it simply changes.
    private var motion: Animation? {
        if reduceMotion { return nil }
        switch notch.phase {
        case .collapsed: return .spring(response: 0.3, dampingFraction: 1)
        case .open, .moment: return .spring(response: 0.42, dampingFraction: 0.78)
        }
    }

    /// The glass arrives late and leaves early, so it's only seen still.
    private func glassFade(showing: Bool) -> Animation? {
        if reduceMotion { return nil }
        return showing ? .easeOut(duration: 0.18).delay(0.2) : .easeIn(duration: 0.08)
    }

    private var shape: NotchShape {
        NotchShape(topRadius: notch.shoulderRadius, bottomRadius: notch.bottomRadius, isFloating: notch.isFloating)
    }

    @ViewBuilder
    private var island: some View {
        ZStack(alignment: .top) {
            background
            // The content may be bigger than the island mid-spring: it hangs
            // over a clear layer, so only the island's own size is laid out,
            // and the shape trims what hasn't been uncovered yet.
            Color.clear
                .overlay(alignment: .top) {
                    content.padding(.horizontal, notch.shoulderRadius)
                }
                .clipShape(shape)
        }
        .contentShape(shape)
    }

    /// One layered background in every state, so opening and closing only
    /// fade layers on the same spring as the shape, never swap views.
    /// Over a real notch: solid black where it meets the notch, so the camera
    /// cutout still disappears, easing into Liquid Glass below it. The one
    /// gradient in the app: it's what lets glass sit on a notch.
    @ViewBuilder
    private var background: some View {
        let expanded = notch.isExpanded
        if notch.isHardware || notch.isFloating {
            let glass = model.settings.notchGlass
            // The floating island meets no camera, so it needn't start solid.
            let band = notch.isFloating ? 0 : min(0.9, notch.notchSize.height / max(notch.size.height, 1))
            ZStack {
                IslandShadow(shape: shape, opacity: expanded ? (glass ? 0.32 : 0.4) : 0, radius: 22, y: 10)
                if glass {
                    Color.clear
                        .glassEffect(.regular, in: shape)
                    // The tint under the glass: black where it meets the notch,
                    // thinning below it as far as the tint setting allows.
                    let amount = model.settings.glassTint
                    let tint = { (frosted: Double, clear: Double) in clear + (frosted - clear) * amount }
                    let top = notch.isFloating ? tint(0.7, 0.22) : 1
                    shape.fill(LinearGradient(
                        stops: [
                            .init(color: .black.opacity(top), location: 0),
                            .init(color: .black.opacity(top), location: band),
                            .init(color: .black.opacity(tint(0.66, 0.2)), location: min(1, band + 0.16)),
                            .init(color: .black.opacity(tint(0.5, 0.08)), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                }
                // Solid while closed, so the tucked island is the notch's own black.
                // It also stays solid while the shape grows or shrinks: glass
                // reshaped every frame smears into a grey slab with a ghost of
                // the board in it. So the island morphs as crisp black, the
                // glass shows through once it has nearly opened, and goes
                // dark again the instant it starts to close.
                shape
                    .fill(.black)
                    .animation(glassFade(showing: expanded)) { $0.opacity(expanded && glass ? 0 : 1) }
            }
        } else {
            ZStack {
                IslandShadow(shape: shape, opacity: expanded ? 0.18 : 0, radius: 18, y: 8)
                Color.clear
                    .glassEffect(.regular, in: shape)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let band = notch.notchSize.height
        // Each state lays out at its final size the moment it arrives, pinned
        // to the top centre, so the island grows around it like a curtain
        // drawing back. Sized by the animating island, it would reflow every
        // frame and slide in from the sides.
        let target = notch.size
        let width = target.width - notch.shoulderRadius * 2
        switch notch.phase {
        case .collapsed:
            LiveEars()
                .frame(width: width, height: band)
                .contentShape(.rect)
                .onTapGesture { actions.open(nil) }
        case .moment:
            if let moment = notch.moment, let session = moment.session {
                AgentMomentView(moment: moment, session: session)
                    .frame(width: width, height: target.height, alignment: .top)
                    .id(moment.id)
                    .transition(reduceMotion ? .identity : .contentReveal)
            } else if let moment = notch.moment {
                MomentView(moment: moment)
                    .frame(width: width, height: target.height, alignment: .top)
                    .id(moment.id)
                    .transition(reduceMotion ? .identity : .contentReveal)
            }
        case .open:
            VStack(spacing: 0) {
                // Beside the notch, the tabs step around the camera; the floating island has none.
                PanelTabStrip(gap: notch.isFloating ? 0 : notch.notchSize.width)
                    .frame(height: notch.notchSize.height)
                if model.isPanelVisible {
                    let tab = notch.tab
                    PanelBlockContent(block: tab)
                        // Fitting tabs report their natural height; the Now tab measures its own board.
                        .fixedSize(horizontal: false, vertical: tab.fitsContent && tab != .now)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                            if tab.fitsContent, tab != .now { notch.measuredHeights[tab] = height }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .id(notch.tab)
                        // Switching tabs is frequent: a quick cross-fade, nothing more.
                        .transition(reduceMotion ? .identity : .opacity.animation(.easeOut(duration: 0.12)))
                }
            }
            .frame(width: width, height: target.height, alignment: .top)
            .transition(reduceMotion ? .identity : .contentReveal)
        }
    }
}

/// The island's drop shadow, on a layer of its own with the island's inside
/// cut out. A `.shadow` on the glass itself renders the glass offscreen, and
/// screen recordings capture that offscreen layer as a solid black box.
private struct IslandShadow: View {
    let shape: NotchShape
    let opacity: Double
    let radius: CGFloat
    let y: CGFloat

    var body: some View {
        shape
            .fill(.black)
            .shadow(color: .black.opacity(opacity), radius: radius, y: y)
            .mask {
                Rectangle()
                    .padding(-(radius * 2 + y))
                    .overlay { shape.blendMode(.destinationOut) }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
    }
}

/// How far content is from arriving: 1 is blurred, faint and a little small.
private struct Reveal: ViewModifier {
    let amount: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 - 0.04 * amount, anchor: .top)
            .blur(radius: 8 * amount)
            .opacity(1 - amount)
    }
}

private extension AnyTransition {
    /// Content comes up out of a soft blur as the island opens over it, a
    /// touch small and growing into place from the top; it leaves at once, so
    /// it's never squeezed by a shrinking shape. The blur only runs for the
    /// fifth of a second it takes to arrive.
    static var contentReveal: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: Reveal(amount: 1), identity: Reveal(amount: 0))
                .animation(.easeOut(duration: 0.26).delay(0.05)),
            removal: .opacity.animation(.easeIn(duration: 0.08))
        )
    }

    /// An ear's icon arrives once the ear has opened, with a little spring.
    static var earContent: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.7)).animation(.spring(duration: 0.36, bounce: 0.2).delay(0.08)),
            removal: .opacity.combined(with: .scale(scale: 0.85)).animation(.easeIn(duration: 0.1))
        )
    }
}


// MARK: - Ears

/// Shown only while an agent works: the apps it's working in on the left,
/// fanned out when there are several, and on the right how many are at it.
/// Nothing here animates in SwiftUI: a looping animation would redraw the
/// island every frame for as long as an agent works, which is most of the day.
/// The right ear's mark is still by default; the moving ones you can pick run
/// on Core Animation instead.
private struct LiveEars: View {
    @Environment(NotchModel.self) private var notch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let working = notch.isLive ? notch.agents.working : []

        HStack(spacing: 0) {
            ZStack {
                if !working.isEmpty {
                    AgentIconStack(sessions: working, size: NotchModel.earIconSize)
                        .transition(reduceMotion ? .identity : .earContent)
                }
            }
            .frame(width: notch.earWidth)

            Group {
                if notch.isFloating {
                    // No camera here: say what's being worked on.
                    Text(LiveEarsLabel.text(working))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contentTransition(.opacity)
                        .transition(reduceMotion ? .identity : .earContent)
                } else {
                    Color.clear
                }
            }
            .frame(width: notch.isFloating ? NotchModel.islandLabelWidth : notch.notchSize.width)

            ZStack {
                if working.count > 1 {
                    Text("\(working.count)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .transition(reduceMotion ? .identity : .earContent)
                } else if !working.isEmpty {
                    AgentMarkView(mark: notch.settings.agentMark)
                        .transition(reduceMotion ? .identity : .earContent)
                }
            }
            .frame(width: notch.earWidth)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(working.isEmpty ? "Clove" : "Clove, \(working.count) agent\(working.count == 1 ? "" : "s") working")
        .accessibilityAddTraits(.isButton)
    }

}

/// What the floating island says between its ears.
enum LiveEarsLabel {
    /// "Fix the hero", or "3 agents working".
    static func text(_ working: [AgentSession]) -> String {
        if working.count > 1 { return "\(working.count) agents working" }
        guard let session = working.first else { return "" }
        return session.title ?? session.project
    }
}

// MARK: - Moment

/// An agent's task starting or ending, as its own card: the app it's in, the
/// conversation, what it's doing, and a glow breathing along the bottom in
/// the app's colours. It holds while the pointer is over it.
private struct AgentMomentView: View {
    @Environment(NotchModel.self) private var notch
    @Environment(\.notchActions) private var actions
    let moment: NotchMoment
    let session: AgentSession

    private var isStart: Bool { moment.action == nil && session.state == .working }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notch.notchSize.height)
            HStack(spacing: 11) {
                AgentAppIcon(session: session, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title ?? session.project)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let action = moment.action {
                    Button(action.title) {
                        notch.clearMoments()
                        notch.phase = .collapsed
                        action.perform()
                    }
                    .buttonStyle(NotchPillButtonStyle(isProminent: true))
                } else {
                    chip
                }
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
        }
        .background(alignment: .bottom) {
            BreathingGlow(colors: glow)
                .frame(height: 64)
                .opacity(moment.tone == .warning ? 0.7 : 1)
        }
        .contentShape(.rect)
        .onHover { notch.isHoveringMoment = $0 }
        .onTapGesture {
            notch.clearMoments()
            actions.open(.now)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(moment.title + (moment.detail.map { ", " + $0 } ?? ""))
    }

    /// Who and what: "Claude in T3 Code · Edit NowBoard.swift", or the agent's last words.
    private var subtitle: String {
        let who: String = {
            guard let host = session.host, !host.name.localizedCaseInsensitiveContains(session.agent.title) else { return session.agent.title }
            return "\(session.agent.title) in \(host.name)"
        }()
        if isStart { return [who, moment.detail].compactMap(\.self).joined(separator: " · ") }
        return moment.detail ?? who
    }

    /// The colours it glows in: the app's, or yellow for a stop or a question.
    private var glow: [Color] {
        moment.tone == .warning ? [Palette.Vivid.yellow, Palette.Vivid.orange] : session.glowColors
    }

    private var chip: some View {
        HStack(spacing: 5) {
            BreathingDot(color: session.glowColors.first ?? Palette.mint)
            Text("Started")
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Color.primary.opacity(0.08), in: .capsule)
    }
}

private struct MomentView: View {
    @Environment(NotchModel.self) private var notch
    @Environment(\.notchActions) private var actions
    let moment: NotchMoment

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notch.notchSize.height)
            HStack(spacing: 12) {
                Image(systemName: moment.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.16), in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(moment.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if let detail = moment.detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if let action = moment.action {
                    Button(action.title) {
                        notch.clearMoments()
                        notch.phase = .collapsed
                        action.perform()
                    }
                    .buttonStyle(NotchPillButtonStyle(isProminent: true))
                }
            }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
        }
        .contentShape(.rect)
        .onHover { notch.isHoveringMoment = $0 }
        .onTapGesture {
            notch.clearMoments()
            actions.open(.now)
        }
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch moment.tone {
        case .done: Palette.mint
        case .neutral: Palette.accent
        case .warning: Palette.Vivid.yellow
        }
    }
}
