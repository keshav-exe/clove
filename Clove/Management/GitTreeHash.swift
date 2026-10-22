import CryptoKit
import Foundation

/// The git tree hash of a folder, computed without git. The `skills` CLI records
/// this as `skillFolderHash`, and GitHub's tree API reports the same value for
/// the folder upstream, so comparing the two tells us whether a skill changed.
enum GitTreeHash {
    static func hash(ofFolder url: URL, fileManager: FileManager = .default) throws -> String {
        hex(try treeDigest(of: url, fileManager: fileManager))
    }

    static func blobHash(of data: Data) -> String {
        hex(objectDigest(type: "blob", body: data))
    }

    private struct Entry {
        let mode: String
        let name: String
        let digest: Data
        let isTree: Bool

        /// Git sorts tree entries as if folder names ended in "/".
        var sortKey: [UInt8] {
            Array(name.utf8) + (isTree ? [UInt8(ascii: "/")] : [])
        }
    }

    private static func treeDigest(of url: URL, fileManager: FileManager) throws -> Data {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isExecutableKey]
        let children = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: []
        )

        var entries: [Entry] = []
        for child in children {
            let name = child.lastPathComponent
            if name == ".git" || name == ".DS_Store" { continue }
            let values = try child.resourceValues(forKeys: Set(keys))

            if values.isSymbolicLink == true {
                let target = try fileManager.destinationOfSymbolicLink(atPath: child.path(percentEncoded: false))
                let digest = objectDigest(type: "blob", body: Data(target.utf8))
                entries.append(Entry(mode: "120000", name: name, digest: digest, isTree: false))
            } else if values.isDirectory == true {
                let digest = try treeDigest(of: child, fileManager: fileManager)
                entries.append(Entry(mode: "40000", name: name, digest: digest, isTree: true))
            } else {
                let data = try Data(contentsOf: child)
                let mode = values.isExecutable == true ? "100755" : "100644"
                entries.append(Entry(mode: mode, name: name, digest: objectDigest(type: "blob", body: data), isTree: false))
            }
        }

        entries.sort { $0.sortKey.lexicographicallyPrecedes($1.sortKey) }

        var body = Data()
        for entry in entries {
            body.append(contentsOf: Array("\(entry.mode) \(entry.name)".utf8))
            body.append(0)
            body.append(entry.digest)
        }
        return objectDigest(type: "tree", body: body)
    }

    private static func objectDigest(type: String, body: Data) -> Data {
        var hasher = Insecure.SHA1()
        hasher.update(data: Data("\(type) \(body.count)\0".utf8))
        hasher.update(data: body)
        return Data(hasher.finalize())
    }

    private static func hex(_ data: Data) -> String {
        let digits = Array("0123456789abcdef".utf8)
        var characters: [UInt8] = []
        characters.reserveCapacity(data.count * 2)
        for byte in data {
            characters.append(digits[Int(byte >> 4)])
            characters.append(digits[Int(byte & 0x0f)])
        }
        return String(decoding: characters, as: UTF8.self)
    }
}
