import Foundation

/// Instructions, rules, commands, and subagents: markdown files, some with
/// frontmatter. Reads only what the list and detail views need.
enum MarkdownResourceParser {
    static func resource(
        at url: URL,
        kind: ResourceKind,
        agent: AgentApp,
        scope: ResourceScope,
        name: String? = nil
    ) -> AgentResource? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let fields = frontmatterFields(text)
        let (matter, body) = SkillFrontmatterParser.parse(text)
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        let resolvedName = name
            ?? matter.name
            ?? url.deletingPathExtension().lastPathComponent
        let summary = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Empty file"
            : (fields["description"].flatMap { $0.isEmpty ? nil : $0 } ?? firstReadableLine(in: body) ?? "")

        var details: [ResourceDetail] = []
        if kind == .rules {
            details.append(ResourceDetail(label: "Applies", value: ruleTrigger(fields)))
            if let globs = fields["globs"], !globs.isEmpty {
                details.append(ResourceDetail(label: "Files", value: globs, isCode: true))
            }
        }
        let linkTarget = url.resolvingSymlinksInPath()
        if linkTarget.path(percentEncoded: false) != url.standardizedFileURL.path(percentEncoded: false) {
            let shown = linkTarget.path(percentEncoded: false).replacing(URL.homeDirectory.path(percentEncoded: false), with: "~/")
            details.append(ResourceDetail(label: "Linked to", value: shown, isCode: true))
        }
        if let model = fields["model"] {
            details.append(ResourceDetail(label: "Model", value: model))
        }
        if let tools = fields["tools"] ?? fields["allowed-tools"] {
            details.append(ResourceDetail(label: "Tools", value: tools, isCode: true))
        }
        if let hint = fields["argument-hint"] {
            details.append(ResourceDetail(label: "Arguments", value: hint, isCode: true))
        }

        return AgentResource(
            id: kind.rawValue + ":" + url.path(percentEncoded: false),
            kind: kind,
            agent: agent,
            scope: scope,
            name: resolvedName,
            summary: summary,
            fileURL: url,
            configKey: nil,
            details: details,
            tokens: tokens(for: kind, text: text, name: resolvedName, summary: summary),
            modifiedAt: modified ?? .distantPast
        )
    }

    /// Instruction files load whole. Commands and subagents only advertise
    /// their name and description until used.
    static func tokens(for kind: ResourceKind, text: String, name: String, summary: String) -> Int? {
        switch kind {
        case .instructions: text.isEmpty ? nil : (text.count + 3) / 4
        case .commands, .subagents: (name.count + summary.count + 16 + 3) / 4
        default: nil
        }
    }

    /// Top-level `key: value` pairs from frontmatter, values unquoted.
    static func frontmatterFields(_ text: String) -> [String: String] {
        let lines = text.replacing("\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return [:] }
        var fields: [String: String] = [:]
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }
            guard line.first != " ", let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = trimmed[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            var value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, let first = value.first, first == "\"" || first == "'", value.last == first {
                value = String(value.dropFirst().dropLast())
            }
            fields[key] = value
        }
        return fields
    }

    /// How a Cursor rule gets attached, in Cursor's own terms.
    static func ruleTrigger(_ fields: [String: String]) -> String {
        if fields["alwaysapply"] == "true" { return "Always" }
        if let globs = fields["globs"], !globs.isEmpty { return "When matching files are open" }
        if let description = fields["description"], !description.isEmpty { return "When the agent decides it's relevant" }
        return "Only when mentioned"
    }

    /// The first heading or sentence a person would read, skipping HTML
    /// comments, tags, and code fences tools leave at the top of files.
    static func firstReadableLine(in body: String) -> String? {
        var inComment = false
        var inFence = false
        for raw in body.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inComment {
                inComment = !line.contains("-->")
                continue
            }
            if line.hasPrefix("<!--") {
                inComment = !line.contains("-->")
                continue
            }
            if inFence || line.isEmpty || line.hasPrefix("<") || line.hasPrefix("---") {
                continue
            }
            let text = line.drop { $0 == "#" || $0 == ">" || $0 == "-" || $0 == "*" }.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { return text }
        }
        return nil
    }
}
