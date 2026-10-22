import Foundation

/// Finds one skill's folder inside an unpacked repository.
enum SkillFolderLocator {
    static func folder(
        for skill: MarketplaceSkill,
        in root: URL,
        hint: String?,
        fileManager: FileManager = .default
    ) throws -> URL {
        if let hint {
            let folder = hint.isEmpty ? root : root.appending(path: hint, directoryHint: .isDirectory)
            if fileManager.fileExists(atPath: folder.appending(path: "SKILL.md").path(percentEncoded: false)) {
                return folder
            }
        }

        let skillFiles = skillFiles(under: root, fileManager: fileManager)
            .sorted { $0.pathComponents.count < $1.pathComponents.count }

        if let named = skillFiles.first(where: { $0.deletingLastPathComponent().lastPathComponent == skill.skillId }) {
            return named.deletingLastPathComponent()
        }

        for file in skillFiles {
            guard let markdown = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let name = SkillFrontmatterParser.parse(markdown).0.name
            if name == skill.skillId || name == skill.name {
                return file.deletingLastPathComponent()
            }
        }

        throw SkillInstaller.Failure.skillNotFound(skill.skillId)
    }

    private static func skillFiles(under root: URL, fileManager: FileManager) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsPackageDescendants]
        ) else { return [] }

        let skipped: Set<String> = ["node_modules", ".git", ".build", "dist", "vendor"]
        var files: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            let name = item.lastPathComponent
            if skipped.contains(name) {
                enumerator.skipDescendants()
            } else if name == "SKILL.md" {
                files.append(item)
            }
        }
        return files
    }
}
