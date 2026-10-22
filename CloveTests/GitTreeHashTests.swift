import Foundation
import Testing
@testable import Clove

struct GitTreeHashTests {
    @Test func blobHashMatchesGit() {
        // printf 'hello\n' | git hash-object --stdin
        #expect(GitTreeHash.blobHash(of: Data("hello\n".utf8)) == "ce013625030ba8dba906f756967f9e9ca394464a")
    }

    @Test func folderHashMatchesGitWriteTree() throws {
        let root = URL.temporaryDirectory.appending(path: "clove-tree-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        try write("---\nname: demo\n---\nBody\n", to: root.appending(path: "SKILL.md"))
        try write("ref\n", to: root.appending(path: "references/guide.md"))
        try write("#!/bin/sh\necho hi\n", to: root.appending(path: "run.sh"))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.appending(path: "run.sh").path(percentEncoded: false))
        try write("x\n", to: root.appending(path: "a-b/f.txt"))
        try write("y\n", to: root.appending(path: "a.txt"))
        // A folder "a" must sort after the file "a.txt", as git compares "a/".
        try write("z\n", to: root.appending(path: "a/z.txt"))

        // Same layout committed with git, then `git rev-parse <tree>:skill`.
        let hash = try GitTreeHash.hash(ofFolder: root)
        #expect(hash == "6ca42fef50e0ca5d85cdaa01d59f01f5568f7806")
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }
}
