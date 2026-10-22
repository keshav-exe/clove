import Foundation
import Testing
@testable import Clove

struct LeftoverScannerTests {
    private func makeFolder(_ url: URL, file: String = "data") throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 2048).write(to: url.appending(path: file))
    }

    @Test func keepsNewestBrowserBuildsAndActiveClaude() async throws {
        let home = URL.temporaryDirectory.appending(path: "clove-left-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }
        let playwright = home.appending(path: "Library/Caches/ms-playwright")
        try makeFolder(playwright.appending(path: "chromium-1200/chrome-mac-arm64/Google Chrome for Testing.app/Contents"))
        try makeFolder(playwright.appending(path: "chromium-1243"))
        try makeFolder(playwright.appending(path: "ffmpeg-1011"))
        try makeFolder(home.appending(path: ".cache/puppeteer/chrome/mac_arm-129.0.6668.58"))
        try makeFolder(home.appending(path: ".cache/puppeteer/chrome/mac_arm-130.0.6723.58"))

        let versions = home.appending(path: ".local/share/claude/versions")
        try FileManager.default.createDirectory(at: versions, withIntermediateDirectories: true)
        for version in ["2.1.289", "2.1.300"] {
            try Data("bin".utf8).write(to: versions.appending(path: version))
        }
        let bin = home.appending(path: ".local/bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: bin.appending(path: "claude"), withDestinationURL: versions.appending(path: "2.1.300"))

        let npx = home.appending(path: ".npm/_npx/abc123")
        try makeFolder(npx)
        try Data(#"{"dependencies": {"@playwright/mcp": "1.0.0"}}"#.utf8).write(to: npx.appending(path: "package.json"))

        let items = await LeftoverScanner.scan(home: home, now: .now.addingTimeInterval(30 * 86_400))
        let outdated = Set(items.filter(\.isOutdated).map(\.url.lastPathComponent))
        #expect(outdated == ["chromium-1200", "mac_arm-129.0.6668.58", "2.1.289", "abc123"])
        #expect(items.first { $0.url.lastPathComponent == "abc123" }?.title == "@playwright/mcp")
        #expect(items.allSatisfy { $0.bytes > 0 })
        #expect(LeftoverScanner.appBundles(in: playwright.appending(path: "chromium-1200")).map(\.lastPathComponent) == ["Google Chrome for Testing.app"])
    }
}
