import Foundation
import Testing
@testable import Clove

struct NotchNeighborsTests {
    @Test func findsRivalsAndPartners() throws {
        let root = URL.temporaryDirectory.appending(path: "neighbors-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["NotchNook.app", "Shotput.app", "Safari.app", "Droppy.app"] {
            try FileManager.default.createDirectory(at: root.appending(path: name), withIntermediateDirectories: true)
        }

        let found = NotchNeighbors.installed(in: [root])
        #expect(found.map(\.name) == ["Droppy", "NotchNook", "Shotput"])
        #expect(found.filter(\.playsAlong).map(\.name) == ["Shotput"])
        #expect(NotchNeighbors.list(found.filter { !$0.playsAlong }) == "Droppy and NotchNook")
    }

    @Test func nothingInstalled() {
        #expect(NotchNeighbors.installed(in: [URL(filePath: "/nonexistent-\(UUID().uuidString)")]).isEmpty)
    }
}
