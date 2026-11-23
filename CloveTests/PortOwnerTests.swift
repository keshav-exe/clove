import Foundation
import Testing
@testable import Clove

struct PortOwnerTests {
    /// Raycast's bundled Node, Figma's agent, AirPlay, and a dev server typed
    /// into Cursor's terminal, which is yours rather than Cursor's.
    private let ps = """
      500     1 02:00:00  9000 /Applications/Raycast.app/Contents/MacOS/Raycast
      510   500 02:00:00  9000 Raycast Backend
      600     1 02:00:00  9000 /Users/me/Library/Application Support/Figma/FigmaAgent.app/Contents/MacOS/figma_agent
      780     1 02:00:00  9000 /System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter
      750     1 02:00:00  9000 /Applications/Cursor.app/Contents/MacOS/Cursor
      760   750 02:00:00  9000 /bin/zsh -il
      770   760 02:00:00  9000 node /Users/me/site/node_modules/.bin/vite
      800     1 02:00:00  9000 /opt/homebrew/opt/postgresql@17/bin/postgres -D /opt/homebrew/var/postgresql@17
      900     1 02:00:00  9000 /usr/local/bin/mystery-daemon
    """

    private let comm = """
      510 /Users/me/Library/Application Support/com.raycast.macos/NodeJS/runtime/22.14.0/bin/node
      770 /opt/homebrew/bin/node
      800 /opt/homebrew/opt/postgresql@17/bin/postgres
    """

    private var found: [RunningProcess] {
        RunningScanner.classify(
            table: ProcessTable.parse(ps, executables: comm),
            ports: [510: [7265], 600: [44950, 44960], 780: [5000, 7000], 770: [5173], 800: [5432], 900: [9999]],
            known: []
        )
    }

    @Test func namesTheAppBehindAPort() {
        let raycast = found.first { $0.pid == 510 }
        #expect(raycast?.kind == .appPort)
        #expect(raycast?.owner?.name == "Raycast")
        #expect(raycast?.owner?.bundlePath == "/Applications/Raycast.app")
        #expect(raycast?.owner?.isSystem == false)

        let figma = found.first { $0.pid == 600 }
        #expect(figma?.kind == .appPort)
        #expect(figma?.ports == [44950, 44960])
    }

    @Test func namesWhatMacOSKeepsOpen() {
        let airplay = found.first { $0.pid == 780 }
        #expect(airplay?.kind == .appPort)
        #expect(airplay?.owner?.name == "AirPlay Receiver")
        #expect(airplay?.owner?.isSystem == true)
    }

    @Test func aServerYouStartedIsADevServer() {
        let vite = found.first { $0.pid == 770 }
        #expect(vite?.kind == .devServer)
        // Typed into Cursor's terminal: the shell makes it yours.
        #expect(vite?.owner == nil)
        #expect(found.first { $0.pid == 800 }?.kind == .devServer)
        // A listener Clove can't name stays out.
        #expect(!found.contains { $0.pid == 900 })
    }

    @Test func frameworkStubAppsAreNotApps() {
        #expect(RunningScanner.bundlePath(of: "/opt/homebrew/Frameworks/Python.framework/Versions/3.13/Resources/Python.app/Contents/MacOS/Python") == nil)
        #expect(RunningScanner.bundlePath(of: "/Applications/Cursor.app/Contents/Frameworks/Cursor Helper.app/Contents/MacOS/Cursor Helper") == "/Applications/Cursor.app")
    }

    @MainActor
    @Test func settingsChooseWhichPortsShow() {
        let defaults = UserDefaults(suiteName: "PortOwnerTests.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        let raycast = found.first { $0.pid == 510 }!
        let airplay = found.first { $0.pid == 780 }!
        #expect(settings.showsInNow(raycast))
        #expect(!settings.showsInNow(airplay))
        settings.hidePorts(of: raycast.owner!)
        #expect(!settings.showsInNow(raycast))
        settings.nowShowsSystemPorts = true
        #expect(settings.showsInNow(airplay))
    }
}

struct UsageLimitsTests {
    @Test func readsClaudeWindows() throws {
        let json = """
        {"five_hour":{"utilization":34.0,"resets_at":"2026-11-24T15:00:00.123+00:00"},
         "seven_day":{"utilization":61,"resets_at":"2026-11-27T09:00:00+00:00"},
         "seven_day_opus":null,
         "extra_usage":{"is_enabled":false}}
        """
        let windows = ClaudeLimitsClient.parseUsage(Data(json.utf8))
        #expect(windows.map(\.title) == ["5-hour", "Weekly"])
        #expect(windows.first?.usedPercent == 34)
        #expect(windows.first?.resetsAt != nil)
        #expect(windows.last?.resetsAt != nil)
    }

    @Test func readsClaudeCredentials() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"t","expiresAt":1900000000000,"subscriptionType":"max"}}"#
        let credentials = try ClaudeLimitsClient.parseCredentials(Data(json.utf8)).get()
        #expect(credentials.plan == "Max")
        #expect(credentials.expiresAt == Date(timeIntervalSince1970: 1_900_000_000))
    }

    @Test func readsCodexWindows() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let json = """
        {"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":7,"limit_window_seconds":18000,"reset_after_seconds":600},
         "secondary_window":{"used_percent":42.5,"limit_window_seconds":604800,"reset_at":1000900}}}
        """
        let limits = CodexLimitsClient.parseUsage(Data(json.utf8), now: now)
        #expect(limits?.plan == "Plus")
        #expect(limits?.windows.map(\.title) == ["5-hour", "Weekly"])
        #expect(limits?.windows.first?.resetsAt == now.addingTimeInterval(600))
        #expect(limits?.windows.last?.usedPercent == 42.5)
    }

    @Test func aResetWindowInAnOldLogReadsEmpty() {
        let line = #"{"timestamp":"2020-01-01T00:00:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":80,"window_minutes":300,"resets_in_seconds":60}}}}"#
        let limits = CodexLimitsClient.parseLogLine(Data(line.utf8))
        #expect(limits?.windows.first?.usedPercent == 0)
    }
}
