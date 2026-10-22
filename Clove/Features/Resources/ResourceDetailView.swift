import SwiftUI

struct ResourceDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    let resource: AgentResource

    @State private var document: MarkdownDocument?
    @State private var isConfirmingTrash = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                ResourceHeader(resource: resource)

                if let problem = resource.problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !resource.details.isEmpty || resource.tokens != nil || usage != nil {
                    SkillDetailSection(title: "Details") {
                        ResourceDetailGrid(resource: resource, usage: usage)
                    }
                }

                switch resource.kind {
                case .commands, .subagents:
                    ResourceShareSection(resource: resource)
                case .mcpServers:
                    MCPShareSection(resource: resource)
                case .instructions:
                    InstructionShareSection(resource: resource)
                default:
                    EmptyView()
                }

                if let document, !document.isEmpty {
                    SkillDetailSection(title: "Contents") {
                        MarkdownView(document: document)
                            .padding(Metrics.spacingL)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background.secondary, in: .rect(cornerRadius: Metrics.controlRadius + 2))
                    }
                }

                SkillDetailSection(title: "Defined In") {
                    ResourceFileRow(resource: resource)
                }
            }
            .padding(Metrics.spacingXL)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(resource.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup {
                if resource.isMarkdown, resource.isFileBacked {
                    Button("Edit", systemImage: "square.and.pencil", action: edit)
                        .keyboardShortcut("e")
                        .help("Edit in Clove (⌘E)")
                }
                ResourceActionsMenu(resource: resource, confirmTrash: { isConfirmingTrash = true })
            }
        }
        .confirmationDialog(
            "Move “\(resource.fileURL.lastPathComponent)” to the Trash?",
            isPresented: $isConfirmingTrash,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive, action: trash)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Agents stop loading it right away. You can put it back from the Trash.")
        }
        .task {
            guard resource.isMarkdown else { return }
            document = await Self.loadDocument(resource.fileURL)
        }
    }

    private var usage: String? {
        guard resource.hasObservableUsage, let report = model.cleanup.usage.value else { return nil }
        if let date = report.lastUsed[resource.usageKey] {
            return "Last used " + date.formatted(.relative(presentation: .named))
        }
        return "No use in your agent history"
    }

    private func edit() {
        openWindow(id: CloveWindowID.editor, value: resource.fileURL)
    }

    private func trash() {
        Task { await model.manager.trash(resource.fileURL) }
    }

    /// The body without frontmatter, parsed off the main actor.
    @concurrent
    private static func loadDocument(_ url: URL) async -> MarkdownDocument? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return MarkdownDocument(SkillFrontmatterParser.parse(text).1)
    }
}
