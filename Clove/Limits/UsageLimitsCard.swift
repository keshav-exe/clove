import SwiftUI

/// How much of each Claude, Codex and Cursor limit is left, as small meters: the
/// five-hour window and the week, side by side.
struct UsageLimitsCard: View {
    @Environment(AppModel.self) private var model

    /// On with something to show, or the one-time invitation.
    static func isShown(_ model: AppModel) -> Bool {
        let settings = model.settings
        if settings.showsUsageLimits { return !model.limits.agents.isEmpty }
        return !settings.dismissedUsageLimitsOffer && UsageLimitsStore.anyInstalled
    }

    var body: some View {
        Group {
            if model.settings.showsUsageLimits {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(model.limits.agents, id: \.self) { agent in
                        if let state = model.limits.states[agent] {
                            AgentLimitsRow(agent: agent, state: state)
                        }
                    }
                }
            } else {
                invitation
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .notchCard()
        .task(id: model.settings.showsUsageLimits) {
            guard model.settings.showsUsageLimits else { return }
            await model.limits.refresh()
        }
    }

    private var invitation: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.07), in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text("See your plan limits")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("Uses the sign-ins Claude Code, Codex and Cursor already saved. No password.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Button("Not Now") {
                withAnimation(.smooth(duration: 0.25)) { model.settings.dismissedUsageLimitsOffer = true }
            }
            .buttonStyle(NotchPillButtonStyle(isProminent: false))
            Button("Turn On") {
                withAnimation(.smooth(duration: 0.25)) {
                    model.settings.dismissedUsageLimitsOffer = true
                    model.settings.showsUsageLimits = true
                }
            }
            .buttonStyle(NotchPillButtonStyle(isProminent: true))
        }
    }
}

/// One agent's limits: who, the current window as a full-width bar with its
/// percent, and a footnote for when it resets and how the week is going.
private struct AgentLimitsRow: View {
    let agent: LimitsAgent
    let state: UsageLimitsStore.State

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(nsImage: agent.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(agent.title)
                        .font(.system(size: 12.5, weight: .semibold))
                    if let plan = state.limits?.plan {
                        Text(plan)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 8)
                    if let window = state.limits?.windows.first {
                        Text("\(Int(window.usedPercent.rounded()))%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(window.usedPercent >= 70 ? LimitStyle.tint(window.usedPercent) : .primary)
                            .contentTransition(.numericText())
                    }
                }
                .lineLimit(1)
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().controlSize(.mini)
        case .failed(let failure):
            Text(failure.message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        case .loaded(let limits):
            if let window = limits.windows.first {
                PaceBar(window: window)
                HStack(spacing: 6) {
                    Text(LimitStyle.footnote(window))
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 6)
                    if let week = limits.windows.dropFirst().first {
                        Text("\(LimitStyle.shortTitle(week.title)) \(Int(week.usedPercent.rounded()))%")
                            .foregroundStyle(week.usedPercent >= 70 ? AnyShapeStyle(LimitStyle.tint(week.usedPercent)) : AnyShapeStyle(.secondary))
                            .help(week.resetsAt.map { "\(week.title) · " + LimitStyle.resetText($0) } ?? week.title)
                    }
                }
                .font(.system(size: 10.5).monospacedDigit())
                .lineLimit(1)
            }
        }
    }
}

/// A window's bar, with a faint tick for how much of the window has gone by.
/// Fill past the tick means you're using it faster than it lasts.
private struct PaceBar: View {
    let window: UsageWindow

    var body: some View {
        let used = window.usedPercent / 100
        let elapsed = window.elapsed()
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                    .frame(height: 5)
                if used > 0.005 {
                    Capsule().fill(LimitStyle.tint(window.usedPercent))
                        .frame(width: max(5, width * used), height: 5)
                }
                if let elapsed, elapsed > 0.02, elapsed < 0.98 {
                    RoundedRectangle(cornerRadius: 0.75)
                        .fill(Color.primary.opacity(0.55))
                        .frame(width: 1.5, height: 11)
                        .offset(x: width * elapsed - 0.75)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 11)
        .animation(.smooth(duration: 0.5), value: window.usedPercent)
        .help(Self.pace(used: used, elapsed: elapsed))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(window.title) limit, \(Int(window.usedPercent.rounded())) percent used")
        .accessibilityValue(Self.pace(used: used, elapsed: elapsed))
    }

    static func pace(used: Double, elapsed: Double?) -> String {
        guard let elapsed else { return "\(Int((used * 100).rounded()))% used" }
        let gone = Int((elapsed * 100).rounded())
        if used > elapsed + 0.1 { return "Ahead of pace: \(Int((used * 100).rounded()))% used with \(gone)% of the window gone" }
        return "On pace: \(Int((used * 100).rounded()))% used with \(gone)% of the window gone"
    }
}

enum LimitStyle {
    /// Quiet while there's room; yellow past 70%, red in the last tenth.
    static func tint(_ percent: Double) -> Color {
        switch percent {
        case 90...: Palette.Vivid.red
        case 70..<90: Palette.Vivid.yellow
        default: Color.primary.opacity(0.8)
        }
    }

    /// "5-hour" → "5h", "Weekly" → "Week", "Weekly · Opus" → "Opus", "30-day" → "30d".
    static func shortTitle(_ title: String) -> String {
        if title.hasSuffix("-hour") { return title.replacing("-hour", with: "h") }
        if title.hasPrefix("Weekly · ") { return String(title.dropFirst("Weekly · ".count)) }
        if title == "Weekly" { return "Week" }
        if title.hasSuffix("-day") { return title.replacing("-day", with: "d") }
        return title
    }

    /// "5h · resets 4:10 PM", "30d · resets Dec 20".
    static func footnote(_ window: UsageWindow, now: Date = .now) -> String {
        let name = shortTitle(window.title)
        guard let reset = window.resetsAt else { return name }
        if reset.timeIntervalSince(now) <= 60 { return "\(name) · resets now" }
        let calendar = Calendar.current
        let when: String
        if calendar.isDate(reset, inSameDayAs: now) {
            when = reset.formatted(date: .omitted, time: .shortened)
        } else if reset.timeIntervalSince(now) < 6 * 86_400 {
            when = reset.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        } else {
            when = reset.formatted(.dateTime.month(.abbreviated).day())
        }
        return "\(name) · resets \(when)"
    }

    /// "Resets in 2 hr 10 min" today; "Resets Thu 9:00" further out.
    static func resetText(_ date: Date, now: Date = .now) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 60 { return "Resets now" }
        if seconds < 24 * 3600 {
            let units: Set<Duration.UnitsFormatStyle.Unit> = seconds < 3600 ? [.minutes] : [.hours, .minutes]
            return "Resets in " + Duration.seconds(seconds).formatted(.units(allowed: units, width: .abbreviated, maximumUnitCount: 2))
        }
        return "Resets " + date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}
