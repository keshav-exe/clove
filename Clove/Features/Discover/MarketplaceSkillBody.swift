import SwiftUI

struct MarketplaceSkillBody: View {
    let detail: MarketplaceDetail

    var body: some View {
        if let audits = detail.page?.audits, !audits.isEmpty {
            SkillDetailSection(title: "Security Audits") {
                SecurityAuditList(audits: audits)
            }
        }

        if let highlights = detail.page?.highlights, !highlights.isEmpty {
            SkillDetailSection(title: "Highlights") {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    ForEach(highlights, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingS) {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(line)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .textSelection(.enabled)
            }
        }

        if let document = detail.document, !document.isEmpty {
            SkillDetailSection(title: detail.file?.path ?? "SKILL.md") {
                MarkdownView(document: document)
                    .padding(Metrics.spacingL)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.secondary, in: .rect(cornerRadius: Metrics.controlRadius + 2))
            }
        }
    }
}
