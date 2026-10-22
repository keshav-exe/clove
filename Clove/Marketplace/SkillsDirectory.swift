import Foundation

/// Fixed addresses for skills.sh and the GitHub hosts skills are fetched from.
enum SkillsDirectory {
    static let site = URL(string: "https://skills.sh")!
    static let rawGitHub = URL(string: "https://raw.githubusercontent.com")!
    static let gitHubAPI = URL(string: "https://api.github.com")!
    static let codeload = URL(string: "https://codeload.github.com")!
}
