import Foundation

/// Things agents download and never clean up.
enum LeftoverKind: String, CaseIterable, Identifiable, Sendable {
    case testBrowsers
    case npxPackages
    case claudeVersions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .testBrowsers: "Test browsers"
        case .npxPackages: "npx packages"
        case .claudeVersions: "Old Claude Code versions"
        }
    }

    /// Where it comes from and why removing it is safe.
    var explanation: String {
        switch self {
        case .testBrowsers:
            "Playwright, Puppeteer, and Selenium download a fresh “Chrome for Testing” for browser tools, and macOS lists each as an app. Older builds are never used again."
        case .npxPackages:
            "MCP servers and tools started with npx keep a full install each. npx downloads them again the next time they run."
        case .claudeVersions:
            "Claude Code keeps every version it updates to. Only the one the claude command points at runs."
        }
    }
}
