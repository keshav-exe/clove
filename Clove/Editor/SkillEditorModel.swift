import Foundation
import Observation

/// One open SKILL.md in an editor window.
@MainActor
@Observable
final class SkillEditorModel {
    enum Mode: String, CaseIterable, Identifiable {
        case write
        case split
        case preview

        var id: String { rawValue }

        var title: String {
            switch self {
            case .write: "Write"
            case .split: "Split"
            case .preview: "Preview"
            }
        }

        var symbolName: String {
            switch self {
            case .write: "pencil"
            case .split: "rectangle.split.2x1"
            case .preview: "eye"
            }
        }
    }

    let fileURL: URL
    var document = SkillDocument(name: "", description: "", body: "")
    var mode: Mode = .split
    private(set) var preview = MarkdownDocument("")
    private(set) var savedDocument: SkillDocument?
    private(set) var loadError: String?
    private(set) var saveError: String?
    private var previewTask: Task<Void, Never>?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// SKILL.md gets name and description fields; other markdown is edited as-is.
    var isSkill: Bool {
        fileURL.lastPathComponent == "SKILL.md"
    }

    var folderName: String {
        fileURL.deletingLastPathComponent().lastPathComponent
    }

    var isLoaded: Bool {
        savedDocument != nil
    }

    var hasChanges: Bool {
        guard let savedDocument else { return false }
        return document != savedDocument
    }

    var issues: [SkillDocumentIssue] {
        isSkill ? SkillDocumentIssue.issues(in: document, folderName: folderName) : []
    }

    var title: String {
        isSkill && !document.name.isEmpty ? document.name : fileURL.lastPathComponent
    }

    func load() async {
        do {
            let text = try await Self.read(fileURL)
            let parsed = isSkill ? SkillDocument(markdown: text) : SkillDocument(name: "", description: "", body: text)
            document = parsed
            savedDocument = parsed
            preview = await Self.parse(parsed.body)
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Re-parses the preview once typing pauses.
    func bodyDidChange() {
        previewTask?.cancel()
        let body = document.body
        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            preview = await Self.parse(body)
        }
    }

    @discardableResult
    func save() -> Bool {
        guard hasChanges else { return true }
        do {
            let text = isSkill ? document.markdown : document.body
            try Data(text.utf8).write(to: fileURL, options: .atomic)
            savedDocument = document
            saveError = nil
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    func clearSaveError() {
        saveError = nil
    }

    func revert() {
        guard let savedDocument else { return }
        document = savedDocument
        bodyDidChange()
    }

    @concurrent
    private static func read(_ url: URL) async throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    /// Frontmatter is metadata, not something to preview.
    @concurrent
    private static func parse(_ body: String) async -> MarkdownDocument {
        MarkdownDocument(SkillFrontmatterParser.parse(body).1)
    }
}
