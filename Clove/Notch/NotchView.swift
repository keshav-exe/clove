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

        island
            .frame(width: size.width, height: size.height, alignment: .top)
            .frame(width: NotchGeometry.canvas.width, height: NotchGeometry.canvas.height, alignment: .top)
            .animation(motion, value: notch.phase)
            .animation(motion, value: size)
            .preferredColorScheme(notch.isHardware ? .dark : nil)
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

    private var shape: NotchShape {
        NotchShape(topRadius: notch.shoulderRadius, bottomRadius: notch.bottomRadius)
    }

    @ViewBuilder
    private var island: some View {
        ZStack(alignment: .top) {
            background
            content
                .padding(.horizontal, notch.shoulderRadius)
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
        if notch.isHardware {
            let glass = model.settings.notchGlass
            let band = min(0.9, notch.notchSize.height / max(notch.size.height, 1))
            ZStack {
                if glass {
                    Color.clear
                        .glassEffect(.regular, in: shape)
                    shape.fill(LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: band),
                            .init(color: .black.opacity(0.5), location: min(1, band + 0.16)),
                            .init(color: .black.opacity(0.32), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                }
                // Solid while closed, so the tucked island is the notch's own black.
                shape
                    .fill(.black)
                    .opacity(expanded && glass ? 0 : 1)
            }
            .shadow(color: .black.opacity(expanded ? (glass ? 0.32 : 0.4) : 0), radius: 22, y: 10)
        } else {
            Color.clear
                .glassEffect(.regular, in: shape)
                .shadow(color: .black.opacity(expanded ? 0.18 : 0), radius: 18, y: 8)
        }
    }

    @ViewBuilder
    private var content: some View {
        let band = notch.notchSize.height
        switch notch.phase {
        case .collapsed:
            LiveEars()
                .frame(height: band)
                .contentShape(.rect)
                .onTapGesture { actions.open(nil) }
        case .moment:
            if let moment = notch.moment {
                MomentView(moment: moment)
                    .id(moment.id)
                    .transition(reduceMotion ? .identity : .contentReveal)
            }
        case .open:
            VStack(spacing: 0) {
                PanelTabStrip(gap: notch.notchSize.width)
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
            .transition(reduceMotion ? .identity : .contentReveal)
        }
    }
}

private extension AnyTransition {
    /// Content waits for the island to start growing, then fades in from just
    /// below full size; it leaves at once, so it's never squeezed by a
    /// shrinking shape. Only opacity and scale: a blur over glass costs frames.
    static var contentReveal: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)).animation(.easeOut(duration: 0.2).delay(0.06)),
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
/// Nothing here animates on its own: a looping animation would redraw the
/// island every frame for as long as an agent works, which is most of the day.
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

            Color.clear
                .frame(width: notch.notchSize.width)

            ZStack {
                if working.count > 1 {
                    Text("\(working.count)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .transition(reduceMotion ? .identity : .earContent)
                } else if !working.isEmpty {
                    Circle()
                        .fill(Palette.mint)
                        .frame(width: 6, height: 6)
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

// MARK: - Moment

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
