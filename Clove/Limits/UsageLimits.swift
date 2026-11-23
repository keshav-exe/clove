import Foundation
import Security

/// One rolling limit on a plan: Claude's five hours, Codex's week.
struct UsageWindow: Identifiable, Hashable, Sendable {
    let id: String
    /// "5-hour", "Weekly", "Weekly · Opus".
    let title: String
    /// 0 to 100.
    let usedPercent: Double
    let resetsAt: Date?
    /// How long the window runs, when known: five hours, a week.
    var length: TimeInterval? = nil

    var isNearlyUsed: Bool { usedPercent >= 90 }

    /// How much of the window has gone by, 0 to 1: set against what's used,
    /// it says whether you're ahead of the pace that lasts.
    func elapsed(at date: Date = .now) -> Double? {
        guard let length, length > 0, let resetsAt else { return nil }
        return min(max(1 - resetsAt.timeIntervalSince(date) / length, 0), 1)
    }
}

/// What one agent's plan has left.
struct AgentLimits: Hashable, Sendable {
    let agent: AgentSession.Agent
    /// "Max", "Pro", "Plus", when the service says.
    let plan: String?
    let windows: [UsageWindow]
    let checkedAt: Date
}

enum LimitsFailure: Error, Equatable, Sendable {
    /// Not signed in, or signed in with an API key, which has no plan limits.
    case notSignedIn(String)
    /// The saved sign-in has expired; opening the agent refreshes it.
    case expired
    /// Keychain access was refused.
    case denied
    case unavailable(String)

    var message: String {
        switch self {
        case .notSignedIn(let detail): detail
        case .expired: "Sign-in expired. Open the agent once to refresh it."
        case .denied: "Clove wasn't allowed to read the sign-in."
        case .unavailable(let detail): detail
        }
    }
}

// MARK: - Claude

/// Claude Code's plan limits, from the same endpoint `/usage` reads, signed in
/// with the token Claude Code keeps in the Keychain. Clove never refreshes the
/// token itself: that would sign Claude Code out.
enum ClaudeLimitsClient {
    struct Credentials: Sendable {
        let accessToken: String
        let plan: String?
        let expiresAt: Date?
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: URL.homeDirectory.appending(path: ".claude").path(percentEncoded: false))
    }

    /// Reads Claude Code's sign-in. The first read shows macOS's Keychain prompt.
    @concurrent
    static func credentials() async -> Result<Credentials, LimitsFailure> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        var data = item as? Data
        if status == errSecUserCanceled || status == errSecAuthFailed || status == errSecInteractionNotAllowed {
            return .failure(.denied)
        }
        if data == nil {
            // Older installs, and Linux-style setups, keep it in a file.
            data = try? Data(contentsOf: URL.homeDirectory.appending(path: ".claude/.credentials.json"))
        }
        guard let data else { return .failure(.notSignedIn("Sign in to Claude Code with your Claude plan to see its limits.")) }
        return parseCredentials(data)
    }

    static func parseCredentials(_ data: Data) -> Result<Credentials, LimitsFailure> {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return .failure(.notSignedIn("Claude Code is signed in with an API key, which has no plan limits.")) }
        let expires = (oauth["expiresAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
        return .success(Credentials(accessToken: token, plan: (oauth["subscriptionType"] as? String).map(\.capitalized), expiresAt: expires))
    }

    @concurrent
    static func fetch(_ credentials: Credentials) async -> Result<AgentLimits, LimitsFailure> {
        if let expires = credentials.expiresAt, expires < .now { return .failure(.expired) }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!, timeoutInterval: 15)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Clove", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 || code == 403 { return .failure(.expired) }
            guard code == 200 else { return .failure(.unavailable("Anthropic didn't answer (\(code)). Clove tries again shortly.")) }
            let windows = parseUsage(data)
            guard !windows.isEmpty else { return .failure(.unavailable("No limits came back for this plan.")) }
            return .success(AgentLimits(agent: .claude, plan: credentials.plan, windows: windows, checkedAt: .now))
        } catch {
            return .failure(.unavailable("Couldn't reach Anthropic. Clove tries again shortly."))
        }
    }

    /// `{"five_hour": {"utilization": 34.0, "resets_at": "…"}, "seven_day": …}`
    static func parseUsage(_ data: Data) -> [UsageWindow] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let names: [(String, String, TimeInterval)] = [
            ("five_hour", "5-hour", 5 * 3600),
            ("seven_day", "Weekly", 7 * 86_400),
            ("seven_day_opus", "Weekly · Opus", 7 * 86_400),
            ("seven_day_sonnet", "Weekly · Sonnet", 7 * 86_400),
        ]
        var windows: [UsageWindow] = names.compactMap { key, title, length in
            guard let window = root[key] as? [String: Any], let used = number(window["utilization"]) else { return nil }
            return UsageWindow(id: key, title: title, usedPercent: clamp(used), resetsAt: (window["resets_at"] as? String).flatMap(date), length: length)
        }
        if let extra = root["extra_usage"] as? [String: Any], extra["is_enabled"] as? Bool == true, let used = number(extra["utilization"]) {
            windows.append(UsageWindow(id: "extra_usage", title: "Extra usage", usedPercent: clamp(used), resetsAt: nil))
        }
        return windows
    }

    static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}

// MARK: - Codex

/// Codex's plan limits, from the endpoint the Codex CLI's `/status` reads,
/// signed in with the ChatGPT token in `~/.codex/auth.json`. Falls back to the
/// limits Codex last wrote into a session log.
enum CodexLimitsClient {
    static var home: URL {
        if let custom = ProcessInfo.processInfo.environment["CODEX_HOME"], !custom.isEmpty {
            return URL(filePath: custom, directoryHint: .isDirectory)
        }
        return URL.homeDirectory.appending(path: ".codex", directoryHint: .isDirectory)
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: home.appending(path: "auth.json").path(percentEncoded: false))
    }

    @concurrent
    static func fetch() async -> Result<AgentLimits, LimitsFailure> {
        guard let data = try? Data(contentsOf: home.appending(path: "auth.json")),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .failure(.notSignedIn("Sign in to Codex with ChatGPT to see its limits.")) }
        guard let tokens = root["tokens"] as? [String: Any], let token = tokens["access_token"] as? String, !token.isEmpty else {
            return local() ?? .failure(.notSignedIn("Codex is signed in with an API key, which has no plan limits."))
        }

        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let account = tokens["account_id"] as? String {
            request.setValue(account, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Clove", forHTTPHeaderField: "User-Agent")
        do {
            let (body, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let limits = parseUsage(body) { return .success(limits) }
            if let fallback = local() { return fallback }
            return .failure(code == 401 || code == 403 ? .expired : .unavailable("OpenAI didn't answer (\(code)). Clove tries again shortly."))
        } catch {
            return local() ?? .failure(.unavailable("Couldn't reach OpenAI. Clove tries again shortly."))
        }
    }

    /// `{"plan_type": "plus", "rate_limit": {"primary_window": {"used_percent": 7,
    /// "limit_window_seconds": 18000, "reset_at": 1730000000}, "secondary_window": …}}`
    static func parseUsage(_ data: Data, now: Date = .now) -> AgentLimits? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let limits = root["rate_limit"] as? [String: Any] else { return nil }
        let windows = [("primary_window", "primary"), ("secondary_window", "secondary")].compactMap { key, id -> UsageWindow? in
            guard let window = limits[key] as? [String: Any], let used = number(window["used_percent"]) else { return nil }
            let seconds = number(window["limit_window_seconds"])
            let reset = number(window["reset_at"]).map { Date(timeIntervalSince1970: $0) }
                ?? number(window["reset_after_seconds"]).map { now.addingTimeInterval($0) }
            return UsageWindow(id: id, title: windowTitle(seconds: seconds, fallback: id == "primary" ? "5-hour" : "Weekly"), usedPercent: clamp(used), resetsAt: reset, length: seconds)
        }
        guard !windows.isEmpty else { return nil }
        return AgentLimits(agent: .codex, plan: (root["plan_type"] as? String).map(planName), windows: windows, checkedAt: now)
    }

    /// The newest `rate_limits` Codex wrote into a session log, for when the
    /// network can't say.
    static func local() -> Result<AgentLimits, LimitsFailure>? {
        let sessions = home.appending(path: "sessions", directoryHint: .isDirectory)
        guard let enumerator = FileManager.default.enumerator(at: sessions, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }
        var files: [(URL, Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if Date.now.timeIntervalSince(modified) < 7 * 86_400 { files.append((url, modified)) }
        }
        for (url, _) in files.sorted(by: { $0.1 > $1.1 }).prefix(6) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n").reversed() where line.contains("\"rate_limits\":{") {
                if let limits = parseLogLine(Data(line.utf8)) { return .success(limits) }
            }
        }
        return nil
    }

    static func parseLogLine(_ data: Data) -> AgentLimits? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["payload"] as? [String: Any],
              let limits = payload["rate_limits"] as? [String: Any] else { return nil }
        let stamp = (root["timestamp"] as? String).flatMap(ClaudeLimitsClient.date) ?? .now
        let windows = ["primary", "secondary"].compactMap { key -> UsageWindow? in
            guard let window = limits[key] as? [String: Any], let used = number(window["used_percent"]) else { return nil }
            let reset = number(window["resets_at"]).map { Date(timeIntervalSince1970: $0) }
                ?? number(window["resets_in_seconds"]).map { stamp.addingTimeInterval($0) }
            // A window that has reset since the log line is back to zero.
            let current = reset.map { $0 < .now } == true ? 0 : used
            let minutes = number(window["window_minutes"])
            return UsageWindow(id: key, title: windowTitle(seconds: minutes.map { $0 * 60 }, fallback: key == "primary" ? "5-hour" : "Weekly"), usedPercent: clamp(current), resetsAt: reset, length: minutes.map { $0 * 60 })
        }
        guard !windows.isEmpty else { return nil }
        return AgentLimits(agent: .codex, plan: (limits["plan_type"] as? String).map(planName), windows: windows, checkedAt: stamp)
    }

    static func windowTitle(seconds: Double?, fallback: String) -> String {
        guard let seconds, seconds > 0 else { return fallback }
        let hours = Int((seconds / 3600).rounded())
        if hours == 168 { return "Weekly" }
        if hours >= 24, hours % 24 == 0 { return "\(hours / 24)-day" }
        return "\(hours)-hour"
    }

    static func planName(_ raw: String) -> String {
        raw.replacing("_", with: " ").capitalized
    }
}

// MARK: - Shared

private func number(_ value: Any?) -> Double? {
    switch value {
    case let value as Double: value
    case let value as Int: Double(value)
    case let value as NSNumber: value.doubleValue
    case let value as String: Double(value)
    default: nil
    }
}

private func clamp(_ percent: Double) -> Double {
    min(max(percent, 0), 100)
}
