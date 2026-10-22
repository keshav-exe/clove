import Foundation

/// Finds API keys exported in plain text from shell profiles, and rewrites
/// those lines to read from the Keychain instead.
enum PlaintextSecretFinder {
    struct Finding: Identifiable, Hashable, Sendable {
        var id: String { file.path(percentEncoded: false) + "#" + name }
        let file: URL
        let line: Int
        let name: String
        let value: String
    }

    static func profiles(home: URL = .homeDirectory) -> [URL] {
        [".zshenv", ".zshrc", ".zprofile", ".bash_profile", ".bashrc"]
            .map { home.appending(path: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
    }

    static func findings(in files: [URL]) -> [Finding] {
        files.flatMap { file -> [Finding] in
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
            return findings(inText: text, file: file)
        }
    }

    /// `export NAME=value` lines whose name or value looks like a credential.
    /// Lines that already compute their value (`$(…)`, `$OTHER`) are skipped.
    static func findings(inText text: String, file: URL) -> [Finding] {
        text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { index, raw in
            guard let (name, value) = export(in: String(raw)),
                  !value.isEmpty,
                  !value.contains("$"), !value.contains("`"),
                  SecretRedactor.looksSensitive(name) || SecretRedactor.looksLikeSecretValue(value)
            else { return nil }
            return Finding(file: file, line: index, name: name, value: value)
        }
    }

    static func export(in line: String) -> (String, String)? {
        var rest = line.trimmingCharacters(in: .whitespaces)
        guard !rest.hasPrefix("#") else { return nil }
        if rest.hasPrefix("export ") {
            rest = String(rest.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
        } else {
            return nil
        }
        guard let equals = rest.firstIndex(of: "=") else { return nil }
        let name = String(rest[..<equals])
        guard SecretVault.isValidName(name) else { return nil }

        var value = String(rest[rest.index(after: equals)...])
        // Drop a trailing comment on unquoted values.
        if let first = value.first, first == "\"" || first == "'" {
            guard let close = value.dropFirst().firstIndex(of: first) else { return nil }
            value = String(value[value.index(after: value.startIndex)..<close])
        } else if let hash = value.range(of: " #") {
            value = String(value[..<hash.lowerBound])
        }
        return (name, value.trimmingCharacters(in: .whitespaces))
    }

    /// Saves each key to the Keychain, then rewrites its line to look it up.
    /// A copy of the original profile goes to the Trash first.
    static func move(_ findings: [Finding]) throws {
        for finding in findings {
            try SecretVault.save(finding.value, named: finding.name)
        }
        for (file, items) in Dictionary(grouping: findings, by: \.file) {
            let target = file.resolvingSymlinksInPath()
            guard let text = try? String(contentsOf: target, encoding: .utf8) else { continue }
            try backUp(target)

            var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            for item in items where item.line < lines.count {
                lines[item.line] = SecretVault.exportLine(item.name) + "  # in Keychain, moved by Clove"
            }
            try Data(lines.joined(separator: "\n").utf8).write(to: target, options: .atomic)
        }
    }

    /// Puts a dated copy of the file in the Trash, so the old version is one drag away.
    private static func backUp(_ file: URL) throws {
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let copy = URL.temporaryDirectory.appending(path: "\(file.lastPathComponent) before Clove \(stamp)")
        try? FileManager.default.removeItem(at: copy)
        try FileManager.default.copyItem(at: file, to: copy)
        try FileManager.default.trashItem(at: copy, resultingItemURL: nil)
    }
}
