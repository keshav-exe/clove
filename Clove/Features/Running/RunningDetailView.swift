import SwiftUI

struct RunningDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let process: RunningProcess
    let isStopping: Bool

    @State private var isConfirmingStop = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    Text(process.name)
                        .font(.title2.weight(.semibold))
                        .textSelection(.enabled)
                    Label(isStopping ? "Stopping…" : "Running", systemImage: "circle.fill")
                        .font(.callout)
                        .foregroundStyle(isStopping ? .orange : .green)
                }

                SkillDetailSection(title: "Details") {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Metrics.spacingL, verticalSpacing: Metrics.spacingS) {
                        if let startedBy = process.startedBy {
                            row("Started by", startedBy)
                        }
                        if let folder = process.folder {
                            row("Folder", folder.path(percentEncoded: false).replacing(URL.homeDirectory.path(percentEncoded: false), with: "~/"), code: true)
                        }
                        if !process.ports.isEmpty {
                            row("Listening on", process.ports.map { "localhost:\($0)" }.joined(separator: ", "), code: true)
                        }
                        row("Running for", process.startedAt.formatted(.relative(presentation: .numeric)).replacing(" ago", with: ""))
                        row("Memory", process.memoryBytes.formatted(.byteCount(style: .memory)))
                        row("Process ID", String(process.pid), code: true)
                    }
                    .font(.callout)
                }

                SkillDetailSection(title: "Command") {
                    MarkdownCodeView(text: process.command)
                }
            }
            .padding(Metrics.spacingXL)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(process.name)
        .toolbar {
            ToolbarItemGroup {
                if let url = process.localURL {
                    Button("Open in Browser", systemImage: "safari") { openURL(url) }
                        .help("Open \(url.absoluteString)")
                }
                if let folder = process.folder {
                    Button("Reveal Folder", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    }
                    .help("Show its working folder in Finder")
                }
                Button(isStopping ? "Force Stop" : "Stop", systemImage: "stop.circle") {
                    if isStopping {
                        model.running.stop(process, force: true)
                    } else {
                        isConfirmingStop = true
                    }
                }
                .help(isStopping ? "Stop it now, without letting it clean up" : "Ask it to quit")
            }
        }
        .confirmationDialog("Stop \(process.name)?", isPresented: $isConfirmingStop, titleVisibility: .visible) {
            Button("Stop", role: .destructive) { model.running.stop(process) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(stopMessage)
        }
    }

    private var stopMessage: String {
        switch process.kind {
        case .agent: "The agent session ends. Unsaved work in it is lost."
        case .mcpServer: "Its agent loses these tools until it restarts the server."
        case .devServer: "The server stops listening on \(process.ports.map { ":\($0)" }.joined(separator: ", "))."
        }
    }

    private func row(_ label: String, _ value: String, code: Bool = false) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .font(code ? .callout.monospaced() : .callout)
                .textSelection(.enabled)
        }
    }
}
