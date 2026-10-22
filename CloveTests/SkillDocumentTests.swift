import Foundation
import Testing
@testable import Clove

struct SkillDocumentTests {
    @Test func keepsUnknownFrontmatterAndBody() {
        let markdown = """
        ---
        name: release-notes
        description: >-
          Writes release notes. Use when
          preparing a release.
        license: MIT
        metadata:
          author: someone
        ---

        # Release Notes

        Steps.
        """

        var document = SkillDocument(markdown: markdown)
        #expect(document.name == "release-notes")
        #expect(document.description == "Writes release notes. Use when preparing a release.")
        #expect(document.extraFrontmatter == ["license: MIT", "metadata:", "  author: someone"])
        #expect(document.body.hasPrefix("# Release Notes"))

        document.description = "Changed: now with a colon"
        let saved = SkillDocument(markdown: document.markdown)
        #expect(saved.description == "Changed: now with a colon")
        #expect(saved.extraFrontmatter == document.extraFrontmatter)
        #expect(saved.body == document.body)
    }

    @Test func quotesOnlyWhenNeeded() {
        #expect(SkillDocument.yamlScalar("Plain words") == "Plain words")
        #expect(SkillDocument.yamlScalar("Key: value") == "\"Key: value\"")
        #expect(SkillDocument.yamlScalar("yes") == "\"yes\"")
        #expect(SkillDocument.yamlScalar("") == "\"\"")
        #expect(SkillDocument.yamlScalar("Say \"hi\": now") == #""Say \"hi\": now""#)
    }

    @Test func quotedValuesRoundTrip() {
        let document = SkillDocument(name: "demo", description: #"Use "quotes": and \ slashes"#, body: "Body")
        #expect(SkillDocument(markdown: document.markdown).description == document.description)
    }

    @Test func fileWithoutFrontmatterIsAllBody() {
        let document = SkillDocument(markdown: "# Title\n\nText")
        #expect(document.name.isEmpty)
        #expect(document.body == "# Title\n\nText")
    }

    @Test func slugAndNameRules() {
        #expect(SkillDocumentIssue.slug(from: "Release Notes!") == "release-notes")
        #expect(SkillDocumentIssue.slug(from: "  --A  B--  ") == "a-b")
        #expect(SkillDocumentIssue.isValidName("release-notes"))
        #expect(!SkillDocumentIssue.isValidName("Release"))
        #expect(!SkillDocumentIssue.isValidName("a--b"))
        #expect(!SkillDocumentIssue.isValidName("-a"))
    }

    @Test func reportsMissingFieldsAsErrors() {
        let issues = SkillDocumentIssue.issues(
            in: SkillDocument(name: "", description: "", body: ""),
            folderName: nil
        )
        #expect(issues.count { $0.severity == .error } == 2)
    }

    @Test func warnsWhenNameDiffersFromFolder() {
        let issues = SkillDocumentIssue.issues(
            in: SkillDocument(name: "demo", description: String(repeating: "Useful words. ", count: 4), body: ""),
            folderName: "other"
        )
        #expect(issues.map(\.severity) == [.warning])
    }
}
