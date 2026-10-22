import Foundation

actor SkillScanner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scan(configuration: ScanConfiguration) async -> [Skill] {
        let urls = skillFiles(configuration: configuration)
        var unique: [String: Skill] = [:]
        unique.reserveCapacity(urls.count)

        await withTaskGroup(of: Skill?.self) { group in
            for url in urls {
                group.addTask {
                    Self.loadSkill(at: url, home: configuration.home)
                }
            }

            for await skill in group {
                guard let skill else { continue }
                unique[skill.id] = skill
            }
        }

        return unique.values.sorted { lhs, rhs in
            if lhs.source != rhs.source {
                return lhs.source < rhs.source
            }
            if lhs.sourceDetail != rhs.sourceDetail {
                return (lhs.sourceDetail ?? "") < (rhs.sourceDetail ?? "")
            }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func skillFiles(configuration: ScanConfiguration) -> [URL] {
        var files: [URL] = []
        let home = configuration.home

        let globalRoots = [
            home.appending(path: ".cursor/skills"),
            home.appending(path: ".cursor/skills-cursor"),
            home.appending(path: ".claude/skills"),
            home.appending(path: ".agents/skills"),
            home.appending(path: ".codex/skills"),
        ]
        for root in globalRoots {
            files.append(contentsOf: skillFiles(under: root, recursive: true))
        }

        if configuration.includePlugins {
            files.append(
                contentsOf: skillFiles(
                    under: home.appending(path: ".cursor/plugins/cache"),
                    recursive: true
                )
            )
        }

        if configuration.includeProjects {
            for projectRoot in configuration.projectRoots {
                files.append(contentsOf: projectSkillFiles(under: projectRoot))
            }
        }

        return files
    }

    private func projectSkillFiles(under root: URL) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let nested = [".cursor/skills", ".claude/skills", ".agents/skills", ".codex/skills"]
        var files: [URL] = []
        for item in contents {
            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }
            for folder in nested {
                files.append(contentsOf: skillFiles(under: item.appending(path: folder), recursive: true))
            }
        }
        return files
    }

    private func skillFiles(under root: URL, recursive: Bool) -> [URL] {
        let rootPath = root.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: rootPath) else { return [] }

        guard recursive else {
            let direct = root.appending(path: "SKILL.md")
            return fileManager.fileExists(atPath: direct.path(percentEncoded: false)) ? [direct] : []
        }

        var files: [URL] = []
        var visited: Set<String> = []
        walk(root, depth: 0, visited: &visited, into: &files)
        return files
    }

    private static let skippedFolders: Set<String> = [
        "node_modules", ".git", "DerivedData", ".build", "Pods", "vendor", ".next", "dist", ".system",
    ]

    /// Walks a skills folder, following symlinked folders. FileManager's
    /// enumerator doesn't descend into them, and linking skills in from a
    /// dotfiles repo or `~/.agents/skills` is how most people share them.
    /// Paths stay as discovered, so a linked skill belongs to the folder it
    /// was linked into. Resolved paths are remembered to stop link cycles.
    private func walk(_ folder: URL, depth: Int, visited: inout Set<String>, into files: inout [URL]) {
        guard depth <= 10 else { return }
        let resolved = folder.resolvingSymlinksInPath().path(percentEncoded: false)
        guard visited.insert(resolved).inserted else { return }
        // Listing a link to a folder fails with "Not a directory", so list the
        // target but build child paths from the folder as discovered.
        guard let names = try? fileManager.contentsOfDirectory(atPath: resolved) else { return }

        for name in names {
            let child = folder.appending(path: name)
            if name == "SKILL.md" {
                files.append(child)
                continue
            }
            guard !Self.skippedFolders.contains(name) else { continue }

            // fileExists follows links, so a linked folder counts as a folder.
            var isDirectory: ObjCBool = false
            guard
                fileManager.fileExists(atPath: child.path(percentEncoded: false), isDirectory: &isDirectory),
                isDirectory.boolValue,
                (try? child.resolvingSymlinksInPath().resourceValues(forKeys: [.isPackageKey]).isPackage) != true
            else { continue }
            walk(child, depth: depth + 1, visited: &visited, into: &files)
        }
    }

    nonisolated static func loadSkill(at url: URL, home: URL) -> Skill? {
        let resolved = url.resolvingSymlinksInPath()
        // Linked if SKILL.md or any folder on the way to it is a link.
        let isSymlink = url.standardizedFileURL.path(percentEncoded: false)
            != resolved.path(percentEncoded: false)
        guard let contents = try? String(contentsOf: resolved, encoding: .utf8) else {
            return nil
        }

        let (matter, _) = SkillFrontmatterParser.parse(contents)
        let directoryName = url.deletingLastPathComponent().lastPathComponent
        let path = resolved.path(percentEncoded: false)
        // Classify by where it was found: a skill linked into ~/.claude/skills
        // is a Claude skill wherever its files live.
        let discovered = url.path(percentEncoded: false)
        let source = SkillSource.classify(path: discovered, home: home.path(percentEncoded: false))
        let modifiedAt = (try? resolved.resourceValues(forKeys: [.contentModificationDateKey]))
            .flatMap(\.contentModificationDate) ?? .now

        return Skill(
            name: matter.name ?? directoryName,
            summary: matter.summary ?? "No description in this skill.",
            originalURL: url,
            fileURL: resolved,
            resolvedPath: path,
            directoryName: directoryName,
            source: source,
            sourceDetail: SkillSource.detail(path: discovered, source: source),
            frontmatterTags: matter.tags,
            modifiedAt: modifiedAt,
            isSymlink: isSymlink,
            installKind: SkillInstallKind.classify(source: source, isSymlink: isSymlink)
        )
    }
}
