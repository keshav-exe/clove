import Foundation

/// Works out when each skill, command, subagent, and MCP server was last used
/// by reading agent transcripts: Claude Code's `Skill` and `Task` calls, slash
/// commands, MCP tool calls, and any agent reading a `…/<name>/SKILL.md`.
/// Subagents are keyed `agent:<name>` and servers `mcp:<name>`.
///
/// Results are cached per file by modification date, so after the first run
/// only new or changed transcripts are read.
actor AgentUsageScanner {
    struct Report: Sendable {
        /// Name to the last time a transcript shows it in use.
        let lastUsed: [String: Date]
        /// The oldest transcript read, so the UI can say how far back history goes.
        let historyStart: Date?
        /// Every session file read, for reclaiming disk space.
        let transcripts: [TranscriptFile]

        var transcriptCount: Int {
            transcripts.count
        }
    }

    private struct CachedFile: Codable {
        let modified: Date
        let size: Int
        let names: [String]
    }

    private let home: URL
    private let cacheURL: URL
    private let fileManager = FileManager.default

    init(home: URL = .homeDirectory, cacheURL: URL = AgentUsageScanner.defaultCache) {
        self.home = home
        self.cacheURL = cacheURL
    }

    static var defaultCache: URL {
        // Versioned: bump when extraction learns new markers, so old entries are re-read.
        URL.applicationSupportDirectory.appending(path: "Clove/usage-cache-v2.json")
    }

    func scan() -> Report {
        var cache = loadCache()
        var nextCache: [String: CachedFile] = [:]
        var lastUsed: [String: Date] = [:]
        var historyStart: Date?
        var transcripts: [TranscriptFile] = []

        for file in transcriptFiles() {
            guard
                let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                let modified = values.contentModificationDate
            else { continue }
            let size = values.fileSize ?? 0
            let key = file.path(percentEncoded: false)

            let names: [String]
            if let cached = cache.removeValue(forKey: key), cached.modified == modified, cached.size == size {
                names = cached.names
            } else {
                names = Self.skillNames(inFile: file)
            }
            nextCache[key] = CachedFile(modified: modified, size: size, names: names)
            transcripts.append(TranscriptFile(url: file, size: size, modified: modified))

            historyStart = min(historyStart ?? modified, modified)
            for name in names where (lastUsed[name] ?? .distantPast) < modified {
                lastUsed[name] = modified
            }
        }

        // Dates survive their transcripts: clearing old history must not make
        // every skill look unused.
        for (name, date) in claudeSkillUsage().merging(loadRemembered(), uniquingKeysWith: max)
            where (lastUsed[name] ?? .distantPast) < date {
            lastUsed[name] = date
        }
        saveRemembered(lastUsed)

        saveCache(nextCache)
        return Report(lastUsed: lastUsed, historyStart: historyStart, transcripts: transcripts)
    }

    /// Claude Code keeps its own per-skill counter in ~/.claude.json.
    private func claudeSkillUsage() -> [String: Date] {
        guard
            let data = try? Data(contentsOf: home.appending(path: ".claude.json")),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let usage = root["skillUsage"] as? [String: Any]
        else { return [:] }
        var dates: [String: Date] = [:]
        for (name, value) in usage {
            guard let milliseconds = (value as? [String: Any])?["lastUsedAt"] as? Double else { continue }
            dates[name] = Date(timeIntervalSince1970: milliseconds / 1000)
        }
        return dates
    }

    private func transcriptFiles() -> [URL] {
        let roots = [
            home.appending(path: ".claude/projects"),
            home.appending(path: ".codex/sessions"),
            home.appending(path: ".cursor/projects"),
        ]
        var files: [URL] = []
        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsPackageDescendants]
            ) else { continue }
            while let item = enumerator.nextObject() as? URL {
                if item.pathExtension == "jsonl" {
                    files.append(item)
                }
            }
        }
        return files
    }

    // MARK: - Extraction

    static func skillNames(inFile url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return [] }
        return Array(skillNames(in: data))
    }

    static func skillNames(in data: Data) -> Set<String> {
        var names: Set<String> = []
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            let bytes = buffer.bindMemory(to: UInt8.self)

            // Claude Code: {"skill":"name"} in a Skill tool call.
            forEach(marker: #"{"skill":""#, in: bytes) { end in
                if let name = token(in: bytes, from: end, forward: true, stop: UInt8(ascii: "\"")) {
                    names.insert(name)
                }
            }
            // Claude Code subagents: {"subagent_type":"name"} in a Task call.
            forEach(marker: #""subagent_type":""#, in: bytes) { end in
                if let name = token(in: bytes, from: end, forward: true, stop: UInt8(ascii: "\"")) {
                    names.insert("agent:" + name)
                }
            }
            // MCP tool calls: "type":"tool_use",…,"name":"mcp__server__tool". Tool
            // lists also name every connected server, so only calls count.
            forEach(marker: #""name":"mcp__"#, in: bytes) { end in
                let start = end - #""name":"mcp__"#.utf8.count
                guard isPreceded(by: "tool_use", in: bytes, before: start, within: 80) else { return }
                if let tool = token(in: bytes, from: end, forward: true, stop: UInt8(ascii: "\"")),
                   let server = tool.components(separatedBy: "__").first, !server.isEmpty {
                    names.insert("mcp:" + server.lowercased())
                }
            }
            // Slash commands: <command-name>/name</command-name>
            forEach(marker: "<command-name>/", in: bytes) { end in
                if let name = token(in: bytes, from: end, forward: true, stop: UInt8(ascii: "<")) {
                    names.insert(name)
                }
            }
            // Any agent reading a skill file: …/name/SKILL.md
            forEach(marker: "/SKILL.md", in: bytes) { end in
                var start = end - "/SKILL.md".utf8.count
                // JSON may escape the slash as "\/".
                if start > 0, bytes[start - 1] == UInt8(ascii: "\\") { start -= 1 }
                if let name = token(in: bytes, from: start, forward: false, stop: UInt8(ascii: "/")) {
                    names.insert(name)
                }
            }
        }

        // Plugin skills are invoked as plugin:skill.
        for name in names where name.contains(":") && !name.hasPrefix("agent:") && !name.hasPrefix("mcp:") {
            if let last = name.split(separator: ":").last {
                names.insert(String(last))
            }
        }
        return names
    }

    /// Calls `body` with the index just past each occurrence of `marker`.
    private static func forEach(marker: String, in bytes: UnsafeBufferPointer<UInt8>, _ body: (Int) -> Void) {
        let needle = Array(marker.utf8)
        guard let base = bytes.baseAddress, bytes.count >= needle.count else { return }
        var offset = 0
        needle.withUnsafeBytes { needleBytes in
            while offset <= bytes.count - needle.count {
                guard let found = memmem(base + offset, bytes.count - offset, needleBytes.baseAddress, needle.count) else {
                    return
                }
                let index = base.distance(to: found.assumingMemoryBound(to: UInt8.self))
                body(index + needle.count)
                offset = index + needle.count
            }
        }
    }

    private static func isPreceded(by marker: String, in bytes: UnsafeBufferPointer<UInt8>, before index: Int, within distance: Int) -> Bool {
        let needle = Array(marker.utf8)
        let start = max(0, index - distance)
        guard index - start >= needle.count else { return false }
        for offset in start...(index - needle.count) {
            var matches = true
            for (position, byte) in needle.enumerated() where bytes[offset + position] != byte {
                matches = false
                break
            }
            if matches { return true }
        }
        return false
    }

    /// A skill-name token next to `index`, read forward or backward until `stop`.
    private static func token(in bytes: UnsafeBufferPointer<UInt8>, from index: Int, forward: Bool, stop: UInt8) -> String? {
        var characters: [UInt8] = []
        var position = forward ? index : index - 1
        while position >= 0, position < bytes.count, characters.count <= 128 {
            let byte = bytes[position]
            if byte == stop { break }
            let isNameByte = (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5a)
                || (byte >= 0x61 && byte <= 0x7a) || byte == UInt8(ascii: "-")
                || byte == UInt8(ascii: "_") || byte == UInt8(ascii: ".") || byte == UInt8(ascii: ":")
            guard isNameByte else { return nil }
            characters.append(byte)
            position += forward ? 1 : -1
        }
        guard !characters.isEmpty, characters.count <= 128 else { return nil }
        if !forward { characters.reverse() }
        return String(decoding: characters, as: UTF8.self)
    }

    // MARK: - Cache

    private var rememberedURL: URL {
        cacheURL.deletingLastPathComponent().appending(path: "usage-last-used.json")
    }

    private func loadRemembered() -> [String: Date] {
        guard let data = try? Data(contentsOf: rememberedURL) else { return [:] }
        return (try? JSONDecoder().decode([String: Date].self, from: data)) ?? [:]
    }

    private func saveRemembered(_ dates: [String: Date]) {
        guard let data = try? JSONEncoder().encode(dates) else { return }
        try? data.write(to: rememberedURL, options: .atomic)
    }

    private func loadCache() -> [String: CachedFile] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [:] }
        return (try? JSONDecoder().decode([String: CachedFile].self, from: data)) ?? [:]
    }

    private func saveCache(_ cache: [String: CachedFile]) {
        try? fileManager.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
