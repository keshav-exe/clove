import SwiftUI

/// What's happening right now: agents at work, servers up, and a line for
/// everything else running. The island's Now tab.
struct NowBoard: View {
    @Environment(AppModel.self) private var model
    @Environment(NotchModel.self) private var notch
    @Environment(\.closePanel) private var closePanel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let sessions = Array(notch.agents.sessions.prefix(3))
        let servers = model.running.items(of: .devServer)

        Group {
            if sessions.isEmpty && servers.isEmpty {
                empty
            } else {
                list(sessions: sessions, servers: servers)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.1), value: sessions.map(\.id))
        .animation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.1), value: servers.map(\.id))
    }

    private func list(sessions: [AgentSession], servers: [RunningProcess]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sessions) { session in
                AgentCard(session: session)
            }
            if !servers.isEmpty {
                ServerList(servers: Array(servers.prefix(6)))
            }
            elsewhere
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var empty: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color.primary.opacity(0.07), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text("All quiet")
                    .font(.system(size: 13, weight: .semibold))
                Text("Agents at work and dev servers show up here while they run.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 16)
    }

    /// MCP servers and containers: worth a count, not a row each.
    @ViewBuilder
    private var elsewhere: some View {
        let mcp = model.running.items(of: .mcpServer).count
        let containers = model.containers.running.count
        if mcp + containers > 0 {
            Button {
                openInClove(model, .running, closePanel: closePanel)
            } label: {
                HStack(spacing: 6) {
                    if mcp > 0 {
                        Label("\(mcp) MCP server\(mcp == 1 ? "" : "s")", systemImage: "server.rack")
                    }
                    if containers > 0 {
                        Label("\(containers) container\(containers == 1 ? "" : "s")", systemImage: "shippingbox")
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .labelStyle(NowCompactLabelStyle())
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Show everything running in Clove")
        }
    }
}

private struct NowCompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.font(.system(size: 10, weight: .semibold))
            configuration.title
        }
        .padding(.trailing, 6)
    }
}

// MARK: - Agent

/// One conversation: who, where, what it's doing, and the file it's changing.
private struct AgentCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel
    let session: AgentSession

    var body: some View {
        let host = HostApp.forAgent(in: session.folder, running: model.running)

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                header
                if session.state == .working {
                    steps
                } else if let summary = session.summary {
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let change = session.change {
                ChangeChip(change: change)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let host, session.change == nil {
                Button {
                    closePanel()
                    host.activate()
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Show in \(host.localizedName ?? "its app")")
                .padding(6)
            }
        }
        .contentShape(.rect(cornerRadius: 16))
        .onTapGesture {
            guard let host else { return }
            closePanel()
            host.activate()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.agent.title) in \(session.project), \(session.statusText)")
    }

    /// The app it's running in, the conversation's name, then who and where
    /// in small type beneath.
    private var header: some View {
        HStack(spacing: 10) {
            AgentAppIcon(session: session, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    // Named conversations read better than two cards both saying the folder.
                    Text(session.title ?? session.project)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    StatusDot(state: session.state)
                    Spacer(minLength: 0)
                }
                Text([session.agent.title, session.title == nil ? nil : session.project, stateWord].compactMap(\.self).joined(separator: " · "))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var stateWord: String {
        switch session.state {
        case .working: "Working"
        case .finished: "Done"
        case .interrupted: "Stopped"
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 4) {
            let recent = session.steps.suffix(2)
            if recent.isEmpty {
                StepRow(symbol: "ellipsis", text: "Thinking", isCurrent: true)
            }
            ForEach(Array(recent)) { step in
                StepRow(
                    symbol: step.isDone ? "checkmark" : "play.fill",
                    text: [step.verb, step.target].compactMap(\.self).joined(separator: " "),
                    isCurrent: !step.isDone
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
}

private struct StepRow: View {
    let symbol: String
    let text: String
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                .frame(width: 12)
            Text(text)
                .font(.system(size: 12, weight: isCurrent ? .medium : .regular))
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// The file being changed, with the lines added and removed this turn.
private struct ChangeChip: View {
    let change: AgentSession.FileChange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(change.name)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack(spacing: 6) {
                if change.added > 0 || change.removed == 0 {
                    Text("+\(change.added)").foregroundStyle(Palette.mint)
                }
                if change.removed > 0 {
                    Text("−\(change.removed)").foregroundStyle(Palette.Vivid.red)
                }
            }
            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
            .contentTransition(.numericText())
        }
        .padding(10)
        .frame(width: 136, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(change.name), \(change.added) lines added, \(change.removed) removed")
    }
}

/// A small dot that breathes while an agent works: enough to say "busy"
/// without drawing the eye.
struct WorkingPulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBright = false

    var body: some View {
        Circle()
            .fill(Color.primary)
            .frame(width: 6, height: 6)
            .opacity(isBright || reduceMotion ? 0.9 : 0.3)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    isBright = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Working pulses; done is a steady mint; stopped is a steady yellow.
private struct StatusDot: View {
    let state: AgentSession.State

    var body: some View {
        Group {
            switch state {
            case .working: WorkingPulse()
            case .finished: Circle().fill(Palette.mint).frame(width: 6, height: 6)
            case .interrupted: Circle().fill(Palette.Vivid.yellow).frame(width: 6, height: 6)
            }
        }
        .frame(width: 6, height: 6)
    }
}

// MARK: - Servers

private struct ServerList: View {
    let servers: [RunningProcess]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(servers) { server in
                ServerRow(server: server)
            }
        }
    }
}

private struct ServerRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel
    let server: RunningProcess
    @State private var isHovered = false

    var body: some View {
        let stopping = model.running.stopping.contains(server.pid)

        HStack(spacing: 8) {
            Circle()
                .fill(stopping ? Palette.Vivid.yellow : Palette.mint)
                .frame(width: 6, height: 6)
            Text(server.ports.first.map { ":\($0)" } ?? server.name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Text([server.name, server.folder?.lastPathComponent].compactMap(\.self).joined(separator: " · "))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            if isHovered, !stopping {
                Button("Stop") {
                    model.running.stop(server)
                }
                .buttonStyle(NotchPillButtonStyle(isProminent: false))
                .transition(.opacity)
            }
            if let url = server.localURL {
                Button("Open") {
                    closePanel()
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(NotchPillButtonStyle(isProminent: true))
                .help("Open \(url.absoluteString)")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(isHovered ? Color.primary.opacity(0.06) : .clear, in: .rect(cornerRadius: 10, style: .continuous))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

/// A small capsule button for the island's dark surface.
struct NotchPillButtonStyle: ButtonStyle {
    var isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(isProminent ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color.primary.opacity(isProminent ? 0.14 : 0.07), in: .capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
