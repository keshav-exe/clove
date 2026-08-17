import Foundation
@testable import Clove

enum TestSkill {
    static func make(
        name: String,
        summary: String,
        path: String,
        directoryName: String,
        source: SkillSource,
        sourceDetail: String? = nil,
        frontmatterTags: [String] = [],
        isSymlink: Bool = false,
        installKind: SkillInstallKind? = nil
    ) -> Skill {
        let url = URL(filePath: path)
        return Skill(
            name: name,
            summary: summary,
            originalURL: url,
            fileURL: url,
            resolvedPath: path,
            directoryName: directoryName,
            source: source,
            sourceDetail: sourceDetail,
            frontmatterTags: frontmatterTags,
            modifiedAt: .now,
            isSymlink: isSymlink,
            installKind: installKind ?? SkillInstallKind.classify(source: source, isSymlink: isSymlink)
        )
    }
}
