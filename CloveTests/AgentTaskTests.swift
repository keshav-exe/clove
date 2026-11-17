import Foundation
import Testing
@testable import Clove

/// A task runs from your message to the agent's last stop, through any pauses
/// for background work.
struct AgentTaskTests {
    private func read(_ entries: [String]) -> AgentSession? {
        AgentTranscriptReader.claude(lines: entries.map { Substring($0) }, id: "t", modified: .now)
    }

    private let prompt = #"{"type":"user","uuid":"p1","timestamp":"2026-11-17T09:00:00.000Z","cwd":"/Users/me/app","message":{"role":"user","content":"Build it"}}"#
    private let launch = #"{"type":"assistant","message":{"stop_reason":"tool_use","content":[{"type":"tool_use","id":"toolu_1","name":"Bash","input":{"command":"xcodebuild","run_in_background":true}}]}}"#
    private let launched = #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"Command running in background with ID: b1"}]}}"#
    private let pause = #"{"type":"assistant","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"Waiting for the build."}]}}"#
    private let notification = #"{"type":"user","message":{"role":"user","content":"<task-notification>\n<task-id>b1</task-id>\n<tool-use-id>toolu_1</tool-use-id>\n<status>completed</status>\n</task-notification>"}}"#
    private let done = #"{"type":"assistant","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"The build passed."}]}}"#

    @Test func pausingForBackgroundWorkIsStillWorking() throws {
        let session = try #require(read([prompt, launch, launched, pause]))
        #expect(session.state == .working)
        #expect(session.backgroundJobs == ["toolu_1"])
    }

    @Test func finishesOnceBackgroundWorkReportsBack() throws {
        let session = try #require(read([prompt, launch, launched, pause, notification, done]))
        #expect(session.state == .finished)
        #expect(session.backgroundJobs.isEmpty)
        #expect(session.promptID == "p1")
        #expect(session.summary == "The build passed.")
        #expect(session.startedAt != nil)
    }

    @Test func aBackgroundReportDoesntStartANewTask() throws {
        let paused = try #require(read([prompt, launch, launched, pause, notification]))
        #expect(paused.promptID == "p1")
    }

    @Test func aFailedRequestEndsTheTaskWithAReason() throws {
        let session = try #require(read([
            prompt,
            #"{"type":"assistant","isApiErrorMessage":true,"message":{"stop_reason":"stop_sequence","content":[{"type":"text","text":"You've hit your usage limit."}]}}"#,
        ]))
        #expect(session.state == .finished)
        #expect(session.failure == "You've hit your usage limit.")
    }

    @Test func endingOnAQuestionIsWaitingOnYou() throws {
        let session = try #require(read([
            prompt,
            #"{"type":"assistant","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"I found two options.\nWhich one should I use?"}]}}"#,
        ]))
        #expect(session.asksQuestion)
    }

    @Test func readsTheJobFromANotification() {
        #expect(AgentTranscriptReader.finishedJob("<task-notification>\n<tool-use-id>toolu_9</tool-use-id>") == "toolu_9")
        #expect(AgentTranscriptReader.finishedJob("Fix the hero") == nil)
    }

    @Test func saysHowLongATaskTook() {
        #expect(NotchLiveMonitor.durationText(30) == nil)
        #expect(NotchLiveMonitor.durationText(240) != nil)
    }
}

struct TempDataTests {
    @Test func findsLeftoversAndKeepsTheNewestDeviceSupport() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "clove-temp-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: home) }
        let manager = FileManager.default
        func file(_ path: String, bytes: Int, age days: Double = 0) throws {
            let url = home.appending(path: path)
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 1, count: bytes).write(to: url)
            let date = Date.now.addingTimeInterval(-days * 86_400)
            try manager.setAttributes([.modificationDate: date], ofItemAtPath: url.path(percentEncoded: false))
        }
        let big = Int(TempDataScanner.minimumBytes) + 1_000_000
        try file("Library/Developer/Xcode/DerivedData/App-abc/Build/x.o", bytes: big)
        try file("Library/Developer/Xcode/iOS DeviceSupport/17.0/Symbols/a", bytes: big, age: 30)
        try file("Library/Developer/Xcode/iOS DeviceSupport/18.0/Symbols/a", bytes: big, age: 1)
        try manager.setAttributes([.modificationDate: Date.now.addingTimeInterval(-30 * 86_400)], ofItemAtPath: home.appending(path: "Library/Developer/Xcode/iOS DeviceSupport/17.0").path(percentEncoded: false))
        try file("Downloads/Thing.dmg", bytes: big, age: 10)
        try file("Downloads/Fresh.dmg", bytes: big, age: 1)
        try file("Downloads/Notes.pdf", bytes: big, age: 10)

        let found = TempDataScanner.scan(home: home)
        let byID = Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0) })

        #expect(byID["derivedData"]?.targets.map(\.url.lastPathComponent) == ["App-abc"])
        #expect(byID["deviceSupport"]?.targets.map(\.url.lastPathComponent) == ["17.0"])
        #expect(byID["installers"]?.targets.map(\.url.lastPathComponent) == ["Thing.dmg"])
        #expect(byID["logs"] == nil)
        // Every target sits directly in its root, the way the Trash move checks.
        for target in found.flatMap(\.targets) {
            #expect(StorageSafety.isDirectChild(target.url, of: target.root))
        }
    }
}
