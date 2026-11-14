import SwiftUI

/// Where each lane sits in the graph gutter. The trunk runs left to its tip;
/// a lane splits off as many trunk commits back as it is behind (log-scaled, so
/// one far-behind branch doesn't flatten the rest), then carries one dot per
/// commit it's ahead.
struct WorktreeGraphLayout {
    static let rowHeight: CGFloat = 52
    static let gutter: CGFloat = 176
    static let leading: CGFloat = 18
    static let tipX: CGFloat = 96
    static let commitSpacing: CGFloat = 9
    static let maxDots = 6

    let maxBehind: Int

    init(lanes: [GitWorktree]) {
        maxBehind = lanes.map(\.behind).max() ?? 0
    }

    func forkX(behind: Int) -> CGFloat {
        guard maxBehind > 0, behind > 0 else { return Self.tipX }
        let share = log1p(Double(behind)) / log1p(Double(maxBehind))
        return Self.tipX - (Self.tipX - Self.leading - 10) * share
    }

    /// The x of each commit dot on a lane; the last stands for any beyond `maxDots`.
    func dots(forkX: CGFloat, ahead: Int) -> [CGFloat] {
        let room = Int((Self.gutter - 12 - (forkX + 16)) / Self.commitSpacing) + 1
        let count = min(ahead, Self.maxDots, max(room, 1))
        return (0..<count).map { forkX + 16 + CGFloat($0) * Self.commitSpacing }
    }

    static func centerY(row: Int) -> CGFloat {
        CGFloat(row) * rowHeight + rowHeight / 2
    }

    /// Lanes that split nearest the tip come first, so a lane's drop from the
    /// trunk never cuts across the lanes above it.
    static func ordered(_ lanes: [GitWorktree]) -> [GitWorktree] {
        lanes.sorted { lhs, rhs in
            if lhs.behind != rhs.behind { return lhs.behind < rhs.behind }
            return (lhs.lastCommit ?? .distantPast) > (rhs.lastCommit ?? .distantPast)
        }
    }
}

/// One repository: the default branch as a trunk and each worktree as a lane
/// off it, drawn behind rows that name the branch and say what state it's in.
struct WorktreeRepositoryGraph: View {
    let repository: GitRepository
    @Binding var selection: GitWorktree.ID?
    let verdict: (GitWorktree) -> WorktreeVerdict

    var body: some View {
        let lanes = WorktreeGraphLayout.ordered(repository.linked)
        let layout = WorktreeGraphLayout(lanes: lanes)
        let main = repository.worktrees.first { $0.isMain }

        ListSection(title: repository.name, note: note) {
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([repository.url])
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(Palette.inkSecondary)
            .help("Show \(repository.name) in Finder")
        } content: {
            VStack(spacing: 0) {
                if let main {
                    row(main, verdict: .blocked(.main))
                }
                ForEach(lanes) { lane in
                    row(lane, verdict: verdict(lane))
                }
            }
            .background(alignment: .topLeading) {
                WorktreeLanes(lanes: lanes, layout: layout, verdict: verdict)
                    .frame(width: WorktreeGraphLayout.gutter)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var note: String {
        let count = repository.linked.count
        let worktrees = count == 1 ? "1 worktree" : "\(count) worktrees"
        guard let branch = repository.defaultBranch else { return worktrees }
        return "\(branch) · \(worktrees)"
    }

    private func row(_ worktree: GitWorktree, verdict: WorktreeVerdict) -> some View {
        SelectableRow(id: worktree.id, selection: $selection) {
            WorktreeLaneRow(worktree: worktree, verdict: verdict, defaultBranch: repository.defaultBranch)
                .padding(.leading, WorktreeGraphLayout.gutter - 12)
                .frame(height: WorktreeGraphLayout.rowHeight - 16)
        }
    }
}

/// The trunk and lanes, drawn natively in one canvas so lines run between rows.
private struct WorktreeLanes: View {
    let lanes: [GitWorktree]
    let layout: WorktreeGraphLayout
    let verdict: (GitWorktree) -> WorktreeVerdict

    var body: some View {
        Canvas { context, size in
            let trunkY = WorktreeGraphLayout.centerY(row: 0)
            let trunkColor = Palette.inkSecondary
            let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

            // Lanes first, so the trunk's fork marks sit on top of them.
            for (index, lane) in lanes.enumerated() {
                let tint = verdict(lane).tint
                let y = WorktreeGraphLayout.centerY(row: index + 1)
                let fork = layout.forkX(behind: lane.behind)
                let dots = layout.dots(forkX: fork, ahead: lane.ahead)
                let end = max(dots.last ?? fork + 12, fork + 12)

                var path = Path()
                path.move(to: CGPoint(x: fork, y: trunkY))
                path.addLine(to: CGPoint(x: fork, y: y - 10))
                path.addQuadCurve(to: CGPoint(x: fork + 10, y: y), control: CGPoint(x: fork, y: y))
                path.addLine(to: CGPoint(x: end, y: y))
                let style = lane.isMissing ? StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 4]) : stroke
                context.stroke(path, with: .color(tint.opacity(0.85)), style: style)

                for (dotIndex, x) in dots.enumerated() {
                    let isOverflow = dotIndex == dots.count - 1 && lane.ahead > dots.count
                    let rect = CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)
                    if isOverflow {
                        context.fill(Path(ellipseIn: rect), with: .color(Palette.surface))
                        context.stroke(Path(ellipseIn: rect), with: .color(tint), lineWidth: 1.5)
                    } else {
                        context.fill(Path(ellipseIn: rect), with: .color(tint))
                    }
                }
                if dots.isEmpty {
                    // No commits of its own: a hollow end, it's just a checkout.
                    let rect = CGRect(x: end - 3.5, y: y - 3.5, width: 7, height: 7)
                    context.fill(Path(ellipseIn: rect), with: .color(Palette.surface))
                    context.stroke(Path(ellipseIn: rect), with: .color(tint), lineWidth: 1.5)
                }
            }

            var trunk = Path()
            trunk.move(to: CGPoint(x: WorktreeGraphLayout.leading, y: trunkY))
            trunk.addLine(to: CGPoint(x: WorktreeGraphLayout.tipX, y: trunkY))
            context.stroke(trunk, with: .color(trunkColor), style: stroke)

            // Where each lane split off.
            for lane in lanes {
                let x = layout.forkX(behind: lane.behind)
                let rect = CGRect(x: x - 3, y: trunkY - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: rect), with: .color(Palette.surface))
                context.stroke(Path(ellipseIn: rect), with: .color(trunkColor), lineWidth: 1.5)
            }
            let tip = CGRect(x: WorktreeGraphLayout.tipX - 4.5, y: trunkY - 4.5, width: 9, height: 9)
            context.fill(Path(ellipseIn: tip), with: .color(Palette.ink))
            _ = size
        }
        .frame(height: WorktreeGraphLayout.rowHeight * CGFloat(lanes.count + 1))
    }
}

/// The words beside a lane: branch, how it stands against the default branch, status.
struct WorktreeLaneRow: View {
    let worktree: GitWorktree
    let verdict: WorktreeVerdict
    let defaultBranch: String?

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Metrics.spacingXS) {
                    Text(worktree.name)
                        .prose(13, .medium)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if worktree.isDetached {
                        Text("detached")
                            .monoLabel()
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                Text(subtitle)
                    .monoLabel()
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !worktree.isMain, worktree.bytes > 0 {
                Text(worktree.bytes.formatted(.byteCount(style: .file)))
                    .monoLabel()
                    .foregroundStyle(Palette.inkSecondary)
            }
            if !worktree.isMain {
                WorktreeStatusMark(verdict: verdict)
                    .frame(minWidth: 112, alignment: .trailing)
            }
        }
    }

    private var subtitle: String {
        if worktree.isMain {
            var parts = ["Main checkout"]
            if let date = worktree.lastCommit {
                parts.append(date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
            }
            return parts.joined(separator: " · ")
        }
        var summary = worktree.graphSummary
        if let agent = worktree.agent { summary = agent + " · " + summary }
        return summary
    }
}
