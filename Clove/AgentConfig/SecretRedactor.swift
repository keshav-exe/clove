import Foundation

/// Masks anything in a command line that looks like a credential, so config
/// details are safe to show on screen.
enum SecretRedactor {
    static let mask = "••••••"

    static func redact(_ text: String) -> String {
        var words: [String] = []
        var maskNext = false
        for word in text.split(separator: " ", omittingEmptySubsequences: false).map(String.init) {
            if maskNext, !word.hasPrefix("-") {
                words.append(mask)
            } else {
                words.append(redactWord(word))
            }
            // --api-key abc: the value is the next word.
            maskNext = word.hasPrefix("-") && !word.contains("=") && looksSensitive(word)
        }
        return words.joined(separator: " ")
    }

    private static func redactWord(_ word: String) -> String {
        // --api-key=abc, TOKEN=abc
        if let equals = word.firstIndex(of: "="), looksSensitive(String(word[..<equals])) {
            return String(word[...equals]) + mask
        }
        return looksLikeSecretValue(word) ? mask : word
    }

    static func looksSensitive(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return ["key", "token", "secret", "password", "auth", "bearer", "credential"].contains { lowered.contains($0) }
    }

    /// Long runs of key-like characters, or well-known key prefixes.
    static func looksLikeSecretValue(_ word: String) -> Bool {
        let prefixes = ["sk-", "ghp_", "gho_", "github_pat_", "xox", "AKIA", "eyJ", "Bearer"]
        if prefixes.contains(where: word.hasPrefix), word.count > 12 { return true }
        guard word.count >= 32, !word.contains("/"), !word.contains(".") else { return false }
        return word.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}
