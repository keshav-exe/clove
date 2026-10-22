import Foundation

/// Installs, links, updates, and removes skills on disk.
///
/// Anything Clove replaces or removes goes to the Trash, never straight to
/// deletion, so a wrong click is always recoverable from Finder.
actor SkillInstaller {
    enum Failure: LocalizedError, Equatable {
        case unsupportedSource
        case invalidName(String)
        case skillNotFound(String)
        case extractionFailed
        case conflict(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedSource:
                "Only skills hosted on GitHub can be installed from Clove. Copy the install command instead."
            case .invalidName(let name):
                "“\(name)” isn't a valid skill folder name."
            case .skillNotFound(let name):
                "Couldn't find “\(name)” in its repository."
            case .extractionFailed:
                "The download couldn't be unpacked."
            case .conflict(let name):
                "A different skill named “\(name)” is already installed."
            }
        }
    }

    nonisolated let home: URL
    nonisolated let lock: SkillLockFile
    private let gitHub: GitHubClient
    private let fileManager = FileManager.default

    init(home: URL = .homeDirectory, gitHub: GitHubClient = GitHubClient()) {
        self.home = home
        lock = .default(home: home)
        self.gitHub = gitHub
    }

    nonisolated var sharedFolder: URL {
        AgentTarget.sharedFolder(home: home)
    }

    // MARK: - Install

    /// Downloads the skill's repository, copies the skill folder into
    /// `~/.agents/skills`, links it into each target, and records it in the lock.
    /// Re-running this for an installed skill is how updates happen.
    @discardableResult
    func install(
        _ skill: MarketplaceSkill,
        folderHint: String? = nil,
        targets: Set<AgentTarget>,
        replacingConflict: Bool = false
    ) async throws -> URL {
        guard skill.isGitHub else { throw Failure.unsupportedSource }
        let name = try Self.validatedName(skill.skillId)
        let destination = sharedFolder.appending(path: name, directoryHint: .isDirectory)

        let existing = lock.entries()[name]
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)),
           existing?.source != skill.source,
           !replacingConflict {
            throw Failure.conflict(name)
        }

        let tarball = try await gitHub.downloadTarball(repo: skill.source)
        let workspace = URL.temporaryDirectory.appending(path: "clove-install-\(UUID().uuidString)")
        defer {
            try? fileManager.removeItem(at: tarball)
            try? fileManager.removeItem(at: workspace)
        }

        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: true)
        try await Self.extract(tarball, into: workspace)
        let repositoryRoot = try repositoryRoot(in: workspace)
        let folder = try SkillFolderLocator.folder(
            for: skill,
            in: repositoryRoot,
            hint: folderHint,
            fileManager: fileManager
        )
        let folderHash = try GitTreeHash.hash(ofFolder: folder)

        try fileManager.createDirectory(at: sharedFolder, withIntermediateDirectories: true)
        let staging = sharedFolder.appending(path: ".\(name).clove-\(UUID().uuidString)")
        try fileManager.copyItem(at: folder, to: staging)

        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.trashItem(at: destination, resultingItemURL: nil)
        }
        try fileManager.moveItem(at: staging, to: destination)

        for target in targets {
            try link(name, to: target)
        }

        let relativeFolder = Self.relativePath(of: folder, in: repositoryRoot)
        try lock.record(
            SkillLockEntry(
                name: name,
                source: skill.source,
                sourceType: "github",
                skillPath: relativeFolder.isEmpty ? "SKILL.md" : relativeFolder + "/SKILL.md",
                folderHash: folderHash,
                installedAt: existing?.installedAt,
                updatedAt: .now
            )
        )
        return destination
    }

    // MARK: - Create

    /// Writes a new skill into `~/.agents/skills` and links it into each target.
    /// Returns the new SKILL.md.
    func create(name: String, markdown: String, targets: Set<AgentTarget>) throws -> URL {
        let name = try Self.validatedName(name)
        let folder = sharedFolder.appending(path: name, directoryHint: .isDirectory)
        let taken = [folder] + targets.map { $0.folder(home: home).appending(path: name) }
        if taken.contains(where: { isSymbolicLink($0) || fileManager.fileExists(atPath: $0.path(percentEncoded: false)) }) {
            throw Failure.conflict(name)
        }

        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "SKILL.md")
        try Data(markdown.utf8).write(to: file, options: .atomic)
        for target in targets {
            try link(name, to: target)
        }
        return file
    }

    // MARK: - Linking

    /// Points `<agent>/skills/<name>` at the shared copy. A symlink that
    /// points somewhere else is replaced; a real folder goes to the Trash first.
    func link(_ name: String, to target: AgentTarget) throws {
        let name = try Self.validatedName(name)
        let agentFolder = target.folder(home: home)
        try fileManager.createDirectory(at: agentFolder, withIntermediateDirectories: true)
        let linkURL = agentFolder.appending(path: name)
        let destination = sharedFolder.appending(path: name)

        if isSymbolicLink(linkURL) {
            let current = try fileManager.destinationOfSymbolicLink(atPath: linkURL.path(percentEncoded: false))
            let resolved = URL(filePath: current, relativeTo: agentFolder).standardizedFileURL
            if resolved.path(percentEncoded: false) == destination.standardizedFileURL.path(percentEncoded: false) {
                return
            }
            try fileManager.removeItem(at: linkURL)
        } else if fileManager.fileExists(atPath: linkURL.path(percentEncoded: false)) {
            try fileManager.trashItem(at: linkURL, resultingItemURL: nil)
        }

        try fileManager.createSymbolicLink(
            atPath: linkURL.path(percentEncoded: false),
            withDestinationPath: Self.relativeLinkTarget(for: target, name: name)
        )
    }

    /// Removes a skill from one agent. Links are removed; real folders are trashed.
    func unlink(_ name: String, from target: AgentTarget) throws {
        let name = try Self.validatedName(name)
        let url = target.folder(home: home).appending(path: name)
        if isSymbolicLink(url) {
            try fileManager.removeItem(at: url)
        } else if fileManager.fileExists(atPath: url.path(percentEncoded: false)) {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        }
    }

    /// Agents whose folder has this skill, either linked or as a real copy.
    func linkedTargets(for name: String) -> Set<AgentTarget> {
        Set(AgentTarget.allCases.filter { target in
            let url = target.folder(home: home).appending(path: name)
            return isSymbolicLink(url) || fileManager.fileExists(atPath: url.path(percentEncoded: false))
        })
    }

    // MARK: - Remove

    /// Moves every home-folder copy of the skill to the Trash and forgets it.
    /// The receipt holds everything needed to put it back.
    @discardableResult
    func uninstall(folders: [URL], name: String) throws -> TrashReceipt {
        var receipt = TrashReceipt()
        if let entry = lock.entries()[name] {
            receipt.lockEntries.append(entry)
        }

        for folder in folders {
            if isSymbolicLink(folder) {
                try removeLink(folder, into: &receipt)
            } else if fileManager.fileExists(atPath: folder.path(percentEncoded: false)) {
                var trashed: NSURL?
                try fileManager.trashItem(at: folder, resultingItemURL: &trashed)
                if let trashed = trashed as URL? {
                    receipt.moves.append(.init(original: folder, trashed: trashed))
                }
            }
        }
        for target in AgentTarget.allCases {
            let url = target.folder(home: home).appending(path: name)
            if isSymbolicLink(url), !fileManager.fileExists(atPath: url.path(percentEncoded: false)) {
                // Dangling now that the shared copy is gone.
                try removeLink(url, into: &receipt)
            }
        }
        try lock.remove(name: name)
        return receipt
    }

    /// Puts back what an uninstall moved to the Trash, as long as it is still there.
    func restore(_ receipt: TrashReceipt) throws {
        for move in receipt.moves where !fileManager.fileExists(atPath: move.original.path(percentEncoded: false)) {
            try fileManager.moveItem(at: move.trashed, to: move.original)
        }
        for link in receipt.links where !isSymbolicLink(link.url) {
            try fileManager.createSymbolicLink(atPath: link.url.path(percentEncoded: false), withDestinationPath: link.destination)
        }
        for entry in receipt.lockEntries {
            try lock.record(entry)
        }
    }

    private func removeLink(_ url: URL, into receipt: inout TrashReceipt) throws {
        let destination = try fileManager.destinationOfSymbolicLink(atPath: url.path(percentEncoded: false))
        try fileManager.removeItem(at: url)
        receipt.links.append(.init(url: url, destination: destination))
    }

    // MARK: - Updates

    /// Lock entries whose folder changed upstream since install. One tree
    /// request per repository keeps this inside GitHub's anonymous limit.
    func entriesWithUpdates(_ entries: [SkillLockEntry]) async throws -> Set<String> {
        let byRepository = Dictionary(grouping: entries.filter(\.isGitHub), by: \.source)
        var updated: Set<String> = []

        for (repository, entries) in byRepository {
            let tree: GitHubClient.Tree
            do {
                tree = try await gitHub.tree(repo: repository)
            } catch GitHubClient.Failure.rateLimited {
                throw GitHubClient.Failure.rateLimited
            } catch {
                // A deleted or private repository has nothing newer to offer.
                continue
            }
            for entry in entries {
                guard let upstream = tree.folderHash(at: entry.folderPath) else { continue }
                if upstream != entry.folderHash {
                    updated.insert(entry.name)
                }
            }
        }
        return updated
    }

    /// True when the installed files no longer match what was installed.
    func isEditedLocally(_ entry: SkillLockEntry) -> Bool {
        let folder = sharedFolder.appending(path: entry.name)
        guard let hash = try? GitTreeHash.hash(ofFolder: folder) else { return false }
        return !entry.folderHash.isEmpty && hash != entry.folderHash
    }

    // MARK: - Helpers

    static func validatedName(_ name: String) throws -> String {
        let valid = !name.isEmpty
            && !name.hasPrefix(".")
            && name.count <= 128
            && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." }
        guard valid else { throw Failure.invalidName(name) }
        return name
    }

    /// `../../.agents/skills/<name>`, relative so the link survives a moved home folder.
    static func relativeLinkTarget(for target: AgentTarget, name: String) -> String {
        let depth = target.relativeFolder.split(separator: "/").count
        return String(repeating: "../", count: depth) + ".agents/skills/" + name
    }

    static func relativePath(of folder: URL, in root: URL) -> String {
        // Temporary folders live under /var, which enumerators report as /private/var.
        let folderPath = folder.resolvingSymlinksInPath().path(percentEncoded: false)
        var rootPath = root.resolvingSymlinksInPath().path(percentEncoded: false)
        if !rootPath.hasSuffix("/") { rootPath += "/" }
        guard folderPath.hasPrefix(rootPath) else { return "" }
        var relative = String(folderPath.dropFirst(rootPath.count))
        if relative.hasSuffix("/") { relative.removeLast() }
        return relative
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path(percentEncoded: false))
        return attributes?[.type] as? FileAttributeType == .typeSymbolicLink
    }

    /// codeload tarballs hold one top-level `owner-repo-sha` folder.
    private func repositoryRoot(in workspace: URL) throws -> URL {
        let children = try fileManager.contentsOfDirectory(
            at: workspace,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        guard children.count == 1, let root = children.first else { throw Failure.extractionFailed }
        return root
    }

    /// bsdtar refuses absolute paths and `..` entries by default.
    private static func extract(_ tarball: URL, into folder: URL) async throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/tar")
        process.arguments = [
            "-xzf", tarball.path(percentEncoded: false),
            "-C", folder.path(percentEncoded: false),
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
        guard status == 0 else { throw Failure.extractionFailed }
    }
}
