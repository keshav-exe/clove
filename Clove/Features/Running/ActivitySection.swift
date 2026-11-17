import AppKit
import SwiftUI

/// How the Mac is doing, in a sentence: cool, warming up, or hot, and how much
/// of it your apps are using. Clove's own share is right there too.
struct MacStatusTile: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let activity = model.running.activity
        let cores = Double(ProcessInfo.processInfo.activeProcessorCount)
        let load = activity.reduce(0) { $0 + $1.cpu } / max(cores, 1)
        let memory = activity.reduce(Int64(0)) { $0 + $1.memoryBytes }
        let clove = activity.first(where: \.isClove)
        let state = ThermalWords(ProcessInfo.processInfo.thermalState)

        Tile {
            HStack(alignment: .center, spacing: Metrics.spacingM) {
                Image(systemName: state.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(state.tint)
                    .frame(width: 36, height: 36)
                    .background(state.tint.opacity(0.12), in: .circle)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.title)
                        .prose(15, .semibold)
                        .foregroundStyle(Palette.ink)
                    Text(activity.isEmpty ? "Measuring…" : "\(state.detail) Your apps are using \(Self.percent(load)) of the processor and \(memory.formatted(.byteCount(style: .memory))) of memory.")
                        .prose(12)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Metrics.spacingM)
                if let clove {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Clove itself")
                            .prose(11)
                            .foregroundStyle(Palette.inkSecondary)
                        Text("\(Self.cpu(clove.cpu)) · \(clove.memoryBytes.formatted(.byteCount(style: .memory)))")
                            .codeLabel(11)
                            .foregroundStyle(Palette.ink)
                    }
                    .help("What Clove is using right now. It reads your processes straight from macOS, without starting other tools.")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    /// Like Activity Monitor: percent of one core, so 250% is two and a half cores.
    static func cpu(_ value: Double) -> String {
        value < 0.5 ? "0%" : value < 10 ? String(format: "%.1f%%", value) : "\(Int(value.rounded()))%"
    }
}

private struct ThermalWords {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal:
            (title, detail, symbol, tint) = ("Running cool", "Nothing is working your Mac hard.", "checkmark", Palette.mint)
        case .fair:
            (title, detail, symbol, tint) = ("Warming up", "A few things are busy; they're at the top below.", "thermometer.low", Palette.Vivid.yellow)
        case .serious:
            (title, detail, symbol, tint) = ("Running hot", "macOS is slowing things down to cool off. Quitting the busiest app helps most.", "thermometer.medium", Palette.Vivid.orange)
        case .critical:
            (title, detail, symbol, tint) = ("Very hot", "Quit what you aren't using, starting at the top.", "thermometer.high", Palette.Vivid.red)
        @unknown default:
            (title, detail, symbol, tint) = ("Running", "", "gauge.with.dots.needle.33percent", Palette.inkSecondary)
        }
    }
}

/// Apps and commands by what they cost: every helper process counted with
/// the app that started it, so Cursor is one row, not forty.
struct ActivitySection: View {
    @Environment(AppModel.self) private var model
    @AppStorage("activity.sort") private var sort = ActivitySort.processor
    @State private var showsAll = false

    var body: some View {
        let groups = sorted(model.running.activity)
        let shown = showsAll ? Array(groups.prefix(40)) : Array(groups.prefix(8))

        if !groups.isEmpty {
            ListSection(title: "Using the most") {
                Picker("Sort by", selection: $sort) {
                    ForEach(ActivitySort.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            } content: {
                ForEach(shown) { group in
                    ActivityRow(group: group, sort: sort)
                }
                if groups.count > 8 {
                    Button(showsAll ? "Show Less" : "Show All \(min(groups.count, 40))") {
                        withAnimation(.easeOut(duration: 0.2)) { showsAll.toggle() }
                    }
                    .buttonStyle(.link)
                    .prose(12)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func sorted(_ groups: [AppActivity]) -> [AppActivity] {
        switch sort {
        case .processor: groups
        case .memory: groups.sorted { $0.memoryBytes > $1.memoryBytes }
        }
    }
}

enum ActivitySort: String, CaseIterable, Identifiable {
    case processor
    case memory

    var id: String { rawValue }
    var title: String {
        switch self {
        case .processor: "Processor"
        case .memory: "Memory"
        }
    }
}

private struct ActivityRow: View {
    @Environment(AppModel.self) private var model
    let group: AppActivity
    let sort: ActivitySort

    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var isConfirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Metrics.spacingM) {
                ActivityIcon(group: group)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Metrics.spacingXS) {
                        Text(group.name)
                            .prose(13, .medium)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        if group.isClove {
                            Text("This app")
                                .prose(11)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    Text(subtitle)
                        .prose(11)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: Metrics.spacingS)

                if isHovered, !group.isClove, !isStopping {
                    Button(isApp ? "Quit" : "Stop") { isConfirming = true }
                        .controlSize(.small)
                        .transition(.opacity)
                }

                Text(MacStatusTile.cpu(group.cpu))
                    .codeLabel(12)
                    .foregroundStyle(sort == .processor ? Palette.ink : Palette.inkSecondary)
                    .frame(width: 56, alignment: .trailing)
                Text(group.memoryBytes.formatted(.byteCount(style: .memory)))
                    .codeLabel(12)
                    .foregroundStyle(sort == .memory ? Palette.ink : Palette.inkSecondary)
                    .frame(width: 72, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Palette.ink.opacity(0.04) : .clear, in: .rect(cornerRadius: 10, style: .continuous))
            .contentShape(.rect(cornerRadius: 10))
            .onHover { isHovered = $0 }
            .onTapGesture {
                guard group.processCount > 1 else { return }
                withAnimation(.easeOut(duration: 0.18)) { isExpanded.toggle() }
            }
            .animation(.easeOut(duration: 0.12), value: isHovered)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.members) { member in
                        HStack(spacing: Metrics.spacingS) {
                            Text(member.name)
                                .prose(11)
                                .foregroundStyle(Palette.inkSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: Metrics.spacingS)
                            Text(MacStatusTile.cpu(member.cpu))
                                .codeLabel(11)
                                .foregroundStyle(Palette.inkSecondary)
                                .frame(width: 56, alignment: .trailing)
                            Text(member.memoryBytes.formatted(.byteCount(style: .memory)))
                                .codeLabel(11)
                                .foregroundStyle(Palette.inkSecondary)
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                    if group.processCount > group.members.count {
                        Text("and \(group.processCount - group.members.count) more")
                            .prose(11)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
                .padding(.leading, 12 + 24 + Metrics.spacingM)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .confirmationDialog(
            isApp ? "Quit \(group.name)?" : "Stop \(group.name)?",
            isPresented: $isConfirming
        ) {
            Button(isApp ? "Quit" : "Stop", role: .destructive) { model.running.end(group) }
        } message: {
            Text(isApp
                ? "\(group.name) quits the way it would from its own menu, so it can ask about unsaved work."
                : "Clove asks it to stop, the way pressing Control-C would.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(MacStatusTile.cpu(group.cpu)) processor, \(group.memoryBytes.formatted(.byteCount(style: .memory)))")
    }

    private var isApp: Bool { group.bundlePath != nil }
    private var isStopping: Bool { model.running.stopping.contains(group.rootPID) }

    private var subtitle: String {
        var parts: [String] = []
        if let folder = group.folder { parts.append((folder as NSString).lastPathComponent) }
        if group.processCount > 1 { parts.append("\(group.processCount) processes") }
        if isStopping { parts.append("Stopping…") }
        if parts.isEmpty { parts.append(isApp ? "App" : "Command") }
        return parts.joined(separator: " · ")
    }
}

/// An app's own icon, or a terminal glyph for a command.
private struct ActivityIcon: View {
    let group: AppActivity

    var body: some View {
        Group {
            if let path = group.bundlePath {
                Image(nsImage: ActivityIcons.icon(path))
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(width: 22, height: 22)
                    .background(Palette.surfaceSunken, in: .rect(cornerRadius: 6, style: .continuous))
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

@MainActor
private enum ActivityIcons {
    static var cache: [String: NSImage] = [:]

    static func icon(_ path: String) -> NSImage {
        if let cached = cache[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache[path] = image
        return image
    }
}
