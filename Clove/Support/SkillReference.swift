import Foundation

/// The string you paste into a chat prompt to attach a skill.
enum SkillReference {
    static func string(for skill: Skill) -> String {
        let name = skill.directoryName
        switch skill.installKind {
        case .homeSymlink, .homeLocal, .plugin, .other:
            return "/\(name)"
        case .project:
            return "@\(name)"
        }
    }
}
