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
                unique[skill.resolvedPath] = skill
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

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        let skipped = ["node_modules", ".git", "DerivedData", ".build", "Pods", "vendor", ".next", "dist"]
        var files: [URL] = []

        while let item = enumerator.nextObject() as? URL {
            let name = item.lastPathComponent
            if skipped.contains(name) {
                enumerator.skipDescendants()
                continue
            }
            if name == ".system" {
                enumerator.skipDescendants()
                continue
            }
            guard name == "SKILL.md" else { continue }
            files.append(item)
        }

        return files
    }

    nonisolated static func loadSkill(at url: URL, home: URL) -> Skill? {
        let isSymlink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
        let resolved = url.resolvingSymlinksInPath()
        guard let contents = try? String(contentsOf: resolved, encoding: .utf8) else {
            return nil
        }

        let (matter, _) = SkillFrontmatterParser.parse(contents)
        let directoryName = resolved.deletingLastPathComponent().lastPathComponent
        let path = resolved.path(percentEncoded: false)
        let source = SkillSource.classify(path: path, home: home.path(percentEncoded: false))
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
            sourceDetail: SkillSource.detail(path: path, source: source),
            frontmatterTags: matter.tags,
            modifiedAt: modifiedAt,
            isSymlink: isSymlink,
            installKind: SkillInstallKind.classify(source: source, isSymlink: isSymlink)
        )
    }
}
