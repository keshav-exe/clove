import AppKit
import Foundation

/// The app an agent conversation is running in: T3 Code, Cursor, Claude,
/// Ghostty. Found from the agent's own process, so a Claude model driven by T3
/// Code shows T3 Code, not Claude.
struct AgentHost: Equatable, Sendable {
    let bundlePath: String
    let bundleID: String?
    let name: String
    /// The agent process inside it, for finding its terminal tab.
    let agentPID: Int32
}

enum AgentHostFinder {
    /// The host of the agent working in `folder`: a process whose command line
    /// names the agent and whose working folder is `folder`, then the nearest
    /// Dock app above it. The newest such process wins.
    ///
    /// A process that names the conversation itself (`--resume <id>`, as T3
    /// Code and the Claude app start them) beats one that only shares its
    /// folder: two apps can each have an agent in the same project.
    static func find(
        folder: String,
        agent: AgentSession.Agent,
        sample: ProcessSample,
        apps: [String: RunningAppInfo],
        workingFolder: (Int32) -> String?,
        conversationID: String? = nil
    ) -> AgentHost? {
        let word = agent == .claude ? "claude" : "codex"
        let named = sample.table.entries.values
            .filter { $0.args.lowercased().contains(word) && !ActivityReport.shells.contains($0.program) }
        let exact = conversationID.map { id in named.filter { $0.args.contains(id) } } ?? []
        let candidates = (exact.isEmpty ? named.filter { workingFolder($0.pid) == folder } : exact)
            .sorted { $0.elapsed < $1.elapsed }

        for candidate in candidates {
            for node in [candidate] + sample.table.ancestors(of: candidate.pid) {
                guard let bundle = ActivityReport.outerBundle(node.executable ?? node.args), let app = apps[bundle] else { continue }
                return AgentHost(bundlePath: bundle, bundleID: app.bundleID, name: app.name, agentPID: candidate.pid)
            }
        }
        return nil
    }

    /// The conversation's ID from its transcript's name: Claude Code names the
    /// file after it, Codex ends its rollout name with it.
    static func conversationID(fromTranscript path: String) -> String? {
        let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        guard name.count >= 36 else { return nil }
        let id = String(name.suffix(36))
        return UUID(uuidString: id) == nil ? nil : id
    }
}

/// Takes you to a conversation in the app it's running in: the editor window
/// for its folder, the terminal tab it's in, or else the app itself.
@MainActor
enum AgentReveal {
    /// Editors open a folder's existing window when asked to open the folder.
    static let editors: Set<String> = [
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.vscodium",
        "com.exafunction.windsurf", "dev.zed.Zed", "com.trae.app",
    ]

    static func show(_ session: AgentSession) {
        guard let host = session.host else {
            fallbackApp(for: session.agent)?.activate()
            return
        }
        let appURL = URL(filePath: host.bundlePath, directoryHint: .isDirectory)
        let bundleID = host.bundleID ?? ""

        if editors.contains(bundleID), let folder = session.folder {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([folder], withApplicationAt: appURL, configuration: configuration)
            return
        }
        if let tty = ProcessMonitor.terminal(of: host.agentPID), selectTab(tty, in: bundleID) {
            return
        }
        let running = NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.path(percentEncoded: false).hasPrefix(host.bundlePath) == true
        }
        if let running {
            running.activate()
        } else {
            NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
        }
    }

    /// Terminal and iTerm can bring a tab forward by its terminal device.
    /// The first time, macOS asks whether Clove may control them.
    private static func selectTab(_ tty: String, in bundleID: String) -> Bool {
        let script: String
        switch bundleID {
        case "com.apple.Terminal":
            script = """
            tell application "Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(tty)" then
                            set selected of t to true
                            set index of w to 1
                            activate
                            return true
                        end if
                    end repeat
                end repeat
            end tell
            return false
            """
        case "com.googlecode.iterm2":
            script = """
            tell application "iTerm2"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            if tty of s is "\(tty)" then
                                select w
                                select t
                                select s
                                activate
                                return true
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
            return false
            """
        default:
            return false
        }
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        return error == nil && result?.booleanValue == true
    }

    private static func fallbackApp(for agent: AgentSession.Agent) -> NSRunningApplication? {
        let bundles = agent == .claude ? ["com.anthropic.claudefordesktop"] : ["com.openai.codex", "com.openai.chat"]
        return bundles.lazy.compactMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first }.first
    }
}
