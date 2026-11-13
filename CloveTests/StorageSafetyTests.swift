import Foundation
import Testing
@testable import Clove

/// Clear Caches and Empty Trash delete for real. These pin down that a delete
/// can only reach what sits directly in the folder it was found in.
final class StorageSafetyTests {
    private let fm = FileManager.default
    private let base: URL
    private var caches: URL { base.appending(path: "Caches", directoryHint: .isDirectory) }
    private var precious: URL { base.appending(path: "precious", directoryHint: .isDirectory) }
    private var preciousFile: String { precious.appending(path: "important.txt").path(percentEncoded: false) }

    init() throws {
        base = fm.temporaryDirectory.appending(path: "clove-storage-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: caches.appending(path: "com.app.real"), withIntermediateDirectories: true)
        try "x".write(to: caches.appending(path: "com.app.real/blob"), atomically: true, encoding: .utf8)
        try fm.createDirectory(at: precious, withIntermediateDirectories: true)
        try "keep".write(to: precious.appending(path: "important.txt"), atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: caches.appending(path: "evil.link"), withDestinationURL: precious)
        try fm.createSymbolicLink(at: caches.appending(path: "com.app.real/inner.link"), withDestinationURL: precious)
    }

    deinit {
        try? fm.removeItem(at: base)
    }

    @Test func emptiesACacheFolderButKeepsIt() throws {
        let folder = caches.appending(path: "com.app.real", directoryHint: .isDirectory)
        #expect(StorageSafety.remove(folder, inside: caches, emptyingFolder: true) == 0)
        #expect(try fm.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).isEmpty)
        #expect(fm.fileExists(atPath: preciousFile), "a link inside the cache is unlinked, not followed")
    }

    @Test func unlinksALinkedCacheFolderWithoutFollowingIt() {
        _ = StorageSafety.remove(caches.appending(path: "evil.link", directoryHint: .isDirectory), inside: caches, emptyingFolder: true)
        #expect(fm.fileExists(atPath: preciousFile))
        #expect(!fm.fileExists(atPath: caches.appending(path: "evil.link").path(percentEncoded: false)))
    }

    @Test func refusesPathsThatLeaveTheFolder() {
        #expect(StorageSafety.remove(caches.appending(path: "../precious", directoryHint: .isDirectory), inside: caches, emptyingFolder: true) == 1)
        #expect(StorageSafety.remove(precious, inside: caches, emptyingFolder: true) == 1)
        #expect(StorageSafety.remove(caches.appending(path: "com.app.real/blob"), inside: caches, emptyingFolder: false) == 1)
        #expect(fm.fileExists(atPath: preciousFile))
    }

    @Test func insideMeansInsideAndNotTheFolderItself() {
        #expect(!StorageSafety.isInside(caches, roots: [caches]))
        #expect(StorageSafety.isInside(caches.appending(path: "com.app.real/blob"), roots: [caches]))
        #expect(!StorageSafety.isInside(caches.appending(path: "evil.link/important.txt"), roots: [caches]))
    }

    @Test func wholeAgentFoldersAreNeverTrashable() {
        let claude = StorageItem(url: URL(filePath: "/Users/someone/.claude"), kind: .developer, bytes: 1, isWholeRoot: true)
        let project = StorageItem(url: URL(filePath: "/Users/someone/Developer/app"), kind: .developer, bytes: 1)
        #expect(!claude.canMoveToTrash)
        #expect(project.canMoveToTrash)
    }
}
