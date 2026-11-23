import SwiftUI

/// What's happening right now: agents at work, servers up, and a line for
/// everything else running. The island's Now tab.
struct NowBoard: View {
    @Environment(AppModel.self) private var model
    @Environment(NotchModel.self) private var notch
    @Environment(\.closePanel) private var closePanel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What the sections draw from, gathered once per redraw.
    private struct Snapshot {
        var sessions: [AgentSession]
        var servers: [RunningProcess]
        var appPorts: [AppPortGroup]
        var busy: [AppActivity]
        var mcp: Int
        var containers: Int
    }

    private var snapshot: Snapshot {
        let settings = model.settings
        return Snapshot(
            sessions: Array(notch.agents.sessions.prefix(3)),
            servers: model.running.items(of: .devServer).filter(settings.showsInNow),
            appPorts: AppPortGroup.groups(model.running.items(of: .appPort).filter(settings.showsInNow)),
            busy: Array(model.running.activity.filter { $0.cpu >= Self.busyPercent && !$0.isClove }.prefix(3)),
            mcp: model.running.items(of: .mcpServer).count,
            containers: model.containers.running.count
        )
    }

    private func hasContent(_ section: NowSection, _ data: Snapshot) -> Bool {
        switch section {
        case .agents: !data.sessions.isEmpty
        case .ports: !data.servers.isEmpty || !data.appPorts.isEmpty
        case .limits: UsageLimitsCard.isShown(model)
        case .busy: !data.busy.isEmpty
        case .elsewhere: data.mcp + data.containers > 0
        }
    }

    var body: some View {
        let data = snapshot
        let visible = model.settings.nowSections.filter { hasContent($0, data) }
        let spring: Animation? = reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.1)

        VStack(spacing: 0) {
            if visible.isEmpty {
                empty
            } else {
                sections(visible, data)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(spring, value: data.sessions.map(\.id))
        .animation(spring, value: data.servers.map(\.id))
        .animation(spring, value: data.appPorts.map(\.id))
        .animation(spring, value: model.settings.nowSections)
    }

    private func sections(_ visible: [NowSection], _ data: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(visible) { section in
                sectionView(section, data)
                    .contextMenu { SectionMenu(section: section) }
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func sectionView(_ section: NowSection, _ data: Snapshot) -> some View {
        switch section {
        case .agents:
            VStack(spacing: 10) {
                ForEach(data.sessions) { AgentCard(session: $0) }
            }
        case .ports:
            ServerList(servers: Array(data.servers.prefix(6)), appPorts: Array(data.appPorts.prefix(max(2, 6 - data.servers.count))))
        case .limits:
            UsageLimitsCard()
        case .busy:
            BusyLine(groups: data.busy)
        case .elsewhere:
            elsewhere(mcp: data.mcp, containers: data.containers)
        }
    }

    /// Half a core, kept up: enough to warm a Mac, and worth a line.
    static let busyPercent: Double = 50

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
                Text("Agents at work, servers and the apps holding ports, and anything working your Mac hard show up here.")
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
    private func elsewhere(mcp: Int, containers: Int) -> some View {
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
            .help("Show everything running in Activity")
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

/// Right-click a section: hide it, or move it up or down the board.
private struct SectionMenu: View {
    @Environment(AppModel.self) private var model
    let section: NowSection

    var body: some View {
        let settings = model.settings
        let index = settings.nowSections.firstIndex(of: section) ?? 0
        if index > 0 {
            Button("Move \(section.title) Up", systemImage: "arrow.up") {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) { settings.moveSection(section, by: -1) }
            }
        }
        if index < settings.nowSections.count - 1 {
            Button("Move \(section.title) Down", systemImage: "arrow.down") {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) { settings.moveSection(section, by: 1) }
            }
        }
        Button("Hide \(section.title)", systemImage: "eye.slash") {
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) { settings.setSection(section, shown: false) }
        }
        Divider()
        Button("Customize Now…", systemImage: "slider.horizontal.3") {
            NSApp.activate()
            SettingsOpener.openNow()
        }
    }
}

// MARK: - Agent

/// One conversation: who, where, what it's doing, and the file it's changing.
private struct AgentCard: View {
    @Environment(\.closePanel) private var closePanel
    let session: AgentSession
    @State private var isHovered = false

    var body: some View {
        let isWorking = session.state == .working
        VStack(alignment: .leading, spacing: 10) {
            header
            if isWorking {
                steps
                    .transition(.opacity)
            } else if let summary = session.summary {
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.3), value: session.steps.map(\.id))
        .animation(.smooth(duration: 0.35), value: session.state)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, isWorking ? 14 : 12)
        .notchCard(isHovered: isHovered, breathing: isWorking ? session.glowColors : nil)
        .contentShape(.rect(cornerRadius: 18))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onTapGesture {
            closePanel()
            AgentReveal.show(session)
        }
        .help("Open this conversation in \(session.host?.name ?? "its app")")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.agent.title) in \(session.project), \(session.statusText)")
        .accessibilityHint("Opens the conversation in \(session.host?.name ?? "its app")")
        .accessibilityAddTraits(.isButton)
    }

    /// The app it's in, the conversation, and its state on the right. On
    /// hover the state gives way to where a click goes.
    private var header: some View {
        HStack(spacing: 10) {
            AgentAppIcon(session: session, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                // Named conversations read better than two cards both saying the folder.
                Text(session.title ?? session.project)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text([who, session.title == nil ? nil : session.project].compactMap(\.self).joined(separator: " · "))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            StateChip(session: session, showsOpen: isHovered)
        }
    }

    /// "Claude in T3 Code" says both the model's maker and where to find it.
    private var who: String {
        guard let host = session.host, !host.name.localizedCaseInsensitiveContains(session.agent.title) else { return session.agent.title }
        return "\(session.agent.title) in \(host.name)"
    }

    /// The step under way, the one before it, and the file being changed.
    private var steps: some View {
        VStack(alignment: .leading, spacing: 5) {
            let recent = session.steps.suffix(2)
            let jobs = session.backgroundJobs.count
            if recent.isEmpty, jobs == 0 {
                StepRow(symbol: "ellipsis", text: "Thinking", isCurrent: true)
            }
            ForEach(Array(recent)) { step in
                StepRow(
                    symbol: step.isDone ? "checkmark" : "arrow.right",
                    text: [step.verb, step.target].compactMap(\.self).joined(separator: " "),
                    isCurrent: !step.isDone
                )
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity))
            }
            if jobs > 0, session.currentStep == nil {
                StepRow(symbol: "hourglass", text: "Waiting on \(jobs) background task\(jobs == 1 ? "" : "s")", isCurrent: true)
                    .transition(.opacity)
            }
            if let change = session.change {
                ChangeLine(change: change)
                    .id(change.name)
                    .transition(.opacity)
                    .padding(.top, 2)
            }
        }
        .padding(.leading, 38)
    }
}

/// Working, done, or stopped, as a small capsule: a breathing dot in the
/// app's colour while it works. On hover it says where a click goes.
private struct StateChip: View {
    let session: AgentSession
    let showsOpen: Bool

    var body: some View {
        HStack(spacing: 5) {
            if showsOpen {
                Text("Open")
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 8.5, weight: .bold))
            } else {
                switch session.state {
                case .working:
                    BreathingDot(color: session.glowColors.first ?? Palette.mint)
                    Text("Working")
                case .finished:
                    Circle().fill(Palette.mint).frame(width: 6, height: 6)
                    Text(Self.ago(session.updatedAt))
                case .interrupted:
                    Circle().fill(Palette.Vivid.yellow).frame(width: 6, height: 6)
                    Text("Stopped")
                }
            }
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(showsOpen ? .primary : .secondary)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Color.primary.opacity(showsOpen ? 0.12 : 0.06), in: .capsule)
        .contentTransition(.opacity)
        .animation(.easeOut(duration: 0.15), value: showsOpen)
    }

    /// "Done", "Done 4m", "Done 2h".
    static func ago(_ date: Date) -> String {
        let minutes = Int(Date.now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "Done" }
        if minutes < 60 { return "Done \(minutes)m" }
        return "Done \(minutes / 60)h"
    }
}

/// A dot that slowly swells and fades, in time with the card's glow.
private struct BreathingDot: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFull = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .scaleEffect(isFull || reduceMotion ? 1 : 0.65)
            .opacity(isFull || reduceMotion ? 1 : 0.5)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true)) { isFull = true }
            }
    }
}

/// The file being changed this turn, in one quiet line.
private struct ChangeLine: View {
    let change: AgentSession.FileChange

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 12)
            Text(change.name)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if change.added > 0 || change.removed == 0 {
                Text("+\(change.added)").foregroundStyle(Palette.mint)
            }
            if change.removed > 0 {
                Text("−\(change.removed)").foregroundStyle(Palette.Vivid.red)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .contentTransition(.numericText())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(change.name), \(change.added) lines added, \(change.removed) removed")
    }
}

private struct StepRow: View {
    let symbol: String
    let text: String
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                .frame(width: 12)
            Text(text)
                .font(.system(size: 11.5, weight: isCurrent ? .medium : .regular))
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
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

// MARK: - Busy

/// The apps working the Mac hardest right now, when any are: the usual reason
/// a laptop gets warm.
private struct BusyLine: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel
    let groups: [AppActivity]
    @State private var isHovered = false

    var body: some View {
        Button {
            openInClove(model, .running, closePanel: closePanel)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "flame")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.Vivid.orange)
                    .frame(width: 12)
                Text(groups.map { "\($0.name) \(MacStatusTile.cpu($0.cpu))" }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                Text("Busy")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .notchCard(radius: 10, isHovered: isHovered)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help("See what's using your Mac in Activity")
        .accessibilityLabel("Busy: " + groups.map { "\($0.name), \(MacStatusTile.cpu($0.cpu)) processor" }.joined(separator: "; "))
    }
}

// MARK: - Servers

private struct ServerList: View {
    let servers: [RunningProcess]
    let appPorts: [AppPortGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(servers) { server in
                ServerRow(server: server)
            }
            ForEach(appPorts) { group in
                AppPortRow(group: group)
            }
        }
        .padding(4)
        .notchCard()
    }
}

/// Every port one app holds, as one row: Logi Options+ keeps four.
struct AppPortGroup: Identifiable, Hashable {
    let owner: PortOwner
    let processes: [RunningProcess]

    var id: String { owner.key }
    var ports: [Int] { Array(Set(processes.flatMap(\.ports))).sorted() }
    /// The programs behind the ports, when they say more than the app's name.
    var programs: [String] {
        var seen: Set<String> = []
        return processes.map(\.name).filter { $0 != owner.name && seen.insert($0).inserted }
    }

    static func groups(_ processes: [RunningProcess]) -> [AppPortGroup] {
        var order: [String] = []
        var byKey: [String: (PortOwner, [RunningProcess])] = [:]
        for process in processes {
            guard let owner = process.owner else { continue }
            if byKey[owner.key] == nil { order.append(owner.key); byKey[owner.key] = (owner, []) }
            byKey[owner.key]?.1.append(process)
        }
        return order.compactMap { key in byKey[key].map { AppPortGroup(owner: $0.0, processes: $0.1) } }
    }
}

/// A port an app holds: whose it is, so `:7265` stops being a mystery.
private struct AppPortRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel
    let group: AppPortGroup
    @State private var isHovered = false

    var body: some View {
        let ports = group.ports
        HStack(spacing: 8) {
            OwnerIcon(owner: group.owner)
            Text(ports.prefix(3).map { ":\($0)" }.joined(separator: " ") + (ports.count > 3 ? " +\(ports.count - 3)" : ""))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .fixedSize()
            Text(([group.owner.name] + group.programs.prefix(1)).joined(separator: " · "))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            if isHovered {
                if group.owner.name == "AirPlay Receiver" {
                    Button("Free") {
                        closePanel()
                        SystemSettingsLink.openAirPlay()
                    }
                    .buttonStyle(NotchPillButtonStyle(isProminent: false))
                    .help("Turn off AirPlay Receiver in System Settings to free :5000 and :7000")
                    .transition(.opacity)
                }
                Button("Hide") {
                    withAnimation(.smooth(duration: 0.25)) { model.settings.hidePorts(of: group.owner) }
                }
                .buttonStyle(NotchPillButtonStyle(isProminent: false))
                .help("Stop listing \(group.owner.name)'s ports here. Settings brings them back.")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(isHovered ? Color.primary.opacity(0.06) : .clear, in: .rect(cornerRadius: 10, style: .continuous))
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help(help)
        .contextMenu {
            ForEach(ports, id: \.self) { port in
                Button("Copy localhost:\(port)") { Pasteboard.copy("localhost:\(port)") }
            }
            Divider()
            if let path = group.owner.bundlePath, !group.owner.isSystem {
                Button("Show \(group.owner.name)") {
                    closePanel()
                    NSWorkspace.shared.openApplication(at: URL(filePath: path), configuration: .init())
                }
            }
            Button("Show in Activity") {
                openInClove(model, .running, closePanel: closePanel) {
                    model.running.selection = group.processes.first?.pid
                }
            }
            Button("Hide \(group.owner.name)'s Ports") {
                model.settings.hidePorts(of: group.owner)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.owner.name) listening on \(ports.map { "port \($0)" }.joined(separator: ", "))")
    }

    private var help: String {
        if group.owner.name == "AirPlay Receiver" {
            return "macOS listens here for AirPlay. Turn off AirPlay Receiver in System Settings if a dev server needs :5000 or :7000."
        }
        return group.owner.isSystem ? "Part of macOS" : "\(group.owner.name) keeps this port open for itself"
    }
}

/// The owning app's icon, or a gear for parts of macOS without one.
private struct OwnerIcon: View {
    let owner: PortOwner

    var body: some View {
        Group {
            if let path = owner.bundlePath {
                Image(nsImage: AppIconCache.icon(path))
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

/// App icons by bundle path. NSWorkspace builds a fresh image on every call,
/// and the board redraws every two seconds while open.
@MainActor
enum AppIconCache {
    private static var icons: [String: NSImage] = [:]

    static func icon(_ path: String) -> NSImage {
        if let icon = icons[path] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icons[path] = icon
        return icon
    }
}

enum SystemSettingsLink {
    /// General › AirDrop & Handoff, where AirPlay Receiver lives.
    @MainActor
    static func openAirPlay() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum Pasteboard {
    @MainActor
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .contextMenu {
            if let url = server.localURL {
                Button("Copy \(url.absoluteString)") { Pasteboard.copy(url.absoluteString) }
            }
            if let folder = server.folder {
                Button("Reveal \(folder.lastPathComponent) in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                }
            }
            Button("Show in Activity") {
                openInClove(model, .running, closePanel: closePanel) {
                    model.running.selection = server.pid
                }
            }
            Divider()
            Button("Stop") { model.running.stop(server) }
        }
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
