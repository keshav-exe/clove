import Foundation

/// Starting points for a new skill. Each body is a scaffold to overwrite,
/// shaped the way agents read skills: what to do, in what order, and how to check it.
enum SkillTemplate: String, CaseIterable, Identifiable, Sendable {
    case blank
    case guide
    case workflow
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: "Blank"
        case .guide: "Guide"
        case .workflow: "Workflow"
        case .review: "Review"
        }
    }

    var summary: String {
        switch self {
        case .blank: "Just the frontmatter."
        case .guide: "Rules and conventions for a tool, codebase, or style."
        case .workflow: "Numbered steps for a repeatable task."
        case .review: "A checklist to audit work against."
        }
    }

    var symbolName: String {
        switch self {
        case .blank: "doc"
        case .guide: "book.closed"
        case .workflow: "list.number"
        case .review: "checklist"
        }
    }

    func body(title: String) -> String {
        switch self {
        case .blank:
            """
            # \(title)

            """
        case .guide:
            """
            # \(title)

            ## When to use

            Describe the situations where an agent should follow this guide.

            ## Rules

            - State each rule as an instruction.
            - Put the reason after it, so the agent can handle edge cases.

            ## Examples

            ```
            Show one correct example.
            ```

            """
        case .workflow:
            """
            # \(title)

            ## Steps

            1. Gather what the task needs before changing anything.
            2. Do the work in small, checkable pieces.
            3. Verify the result, then report what changed.

            ## Done when

            - The result is verified, not assumed.

            """
        case .review:
            """
            # \(title)

            Review the work against each item. Report only real problems, most severe first.

            ## Checklist

            - [ ] First thing to check
            - [ ] Second thing to check

            ## Output

            For each problem: where it is, what's wrong, and the fix.

            """
        }
    }
}
