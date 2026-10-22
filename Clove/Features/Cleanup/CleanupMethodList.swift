import SwiftUI

/// Plain answers to "why is this on the list?"
struct CleanupMethodList: View {
    let report: AgentUsageScanner.Report
    let window: CleanupWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            CleanupMethodRow(symbolName: "clock.arrow.circlepath", text: historyLine)
            CleanupMethodRow(
                symbolName: "calendar",
                text: "Lists skills, commands, and subagents no session used in the last \(window.phrase). Anything added or edited since then is left alone."
            )
            CleanupMethodRow(
                symbolName: "puzzlepiece.extension",
                text: "Never lists plugin, built-in, or project items. They belong to something else."
            )
            CleanupMethodRow(
                symbolName: "arrow.uturn.backward",
                text: "Moves files to the Trash. Undo right after, or put them back from the Trash later."
            )
        }
    }

    private var historyLine: String {
        let sessions = report.transcriptCount.formatted()
        guard let start = report.historyStart else {
            return "Reads \(sessions) Claude Code, Codex, and Cursor sessions on this Mac."
        }
        let since = start.formatted(.dateTime.month(.abbreviated).day().year())
        return "Reads \(sessions) Claude Code, Codex, and Cursor sessions on this Mac, back to \(since). Nothing leaves your Mac."
    }
}
