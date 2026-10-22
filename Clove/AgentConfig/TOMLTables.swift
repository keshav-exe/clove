import Foundation

/// Just enough TOML to read Codex's config: named tables under a prefix and
/// their single-line `key = value` pairs. Values stay raw text.
enum TOMLTables {
    /// `[prefix.name]` tables, keyed by `name`. Sub-tables like `[prefix.name.env]` are skipped.
    static func tables(in text: String, prefix: String) -> [String: [String: String]] {
        var tables: [String: [String: String]] = [:]
        var current: String?

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                current = nil
                guard let path = headerPath(line), path.count == 2, path[0] == prefix else { continue }
                current = path[1]
                if tables[path[1]] == nil {
                    tables[path[1]] = [:]
                }
                continue
            }
            guard let current, !line.hasPrefix("#"), let equals = line.firstIndex(of: "=") else { continue }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            tables[current]?[key] = value
        }
        return tables
    }

    /// Keys of `[prefix.name.*]` sub-tables, like an `env` table's variable names.
    static func subtableKeys(in text: String, table prefix: String, name: String) -> [String] {
        var keys: [String] = []
        var inside = false
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                let path = headerPath(line) ?? []
                inside = path.count == 3 && path[0] == prefix && path[1] == name
                continue
            }
            guard inside, !line.hasPrefix("#"), let equals = line.firstIndex(of: "=") else { continue }
            keys.append(line[..<equals].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
        }
        return keys
    }

    /// `[a."b c".d]` → ["a", "b c", "d"]
    static func headerPath(_ line: String) -> [String]? {
        guard line.hasPrefix("["), !line.hasPrefix("[["), let close = line.lastIndex(of: "]") else { return nil }
        let inner = line[line.index(after: line.startIndex)..<close]
        var parts: [String] = []
        var current = ""
        var inQuotes = false
        for character in inner {
            if character == "\"" {
                inQuotes.toggle()
            } else if character == ".", !inQuotes {
                parts.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current.trimmingCharacters(in: .whitespaces))
        return parts
    }

    static func string(_ raw: String) -> String? {
        guard raw.count >= 2, raw.hasPrefix("\""), raw.hasSuffix("\"") else { return nil }
        return String(raw.dropFirst().dropLast())
    }

    /// `["a", "b"]` on one line → ["a", "b"]. Multi-line arrays come back empty.
    static func array(_ raw: String) -> [String] {
        guard raw.hasPrefix("["), raw.hasSuffix("]") else { return [] }
        return raw.dropFirst().dropLast()
            .split(separator: ",")
            .compactMap { string($0.trimmingCharacters(in: .whitespaces)) }
    }
}
