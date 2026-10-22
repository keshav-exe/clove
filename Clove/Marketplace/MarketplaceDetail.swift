import Foundation

/// Everything the detail pane shows for a skills.sh listing.
struct MarketplaceDetail: Sendable {
    var page: SkillPageDetails?
    var file: RemoteSkillFile?
    var document: MarkdownDocument?
    /// Frontmatter description first, then the skills.sh summary.
    var summary: String?

    init(page: SkillPageDetails?, file: RemoteSkillFile?) {
        self.page = page
        self.file = file
        if let file {
            let (matter, body) = SkillFrontmatterParser.parse(file.markdown)
            document = MarkdownDocument(body)
            summary = matter.summary ?? page?.description
        } else {
            document = page.map { MarkdownDocument(paragraphs: $0.renderedBody) }
            summary = page?.description
        }
    }
}
