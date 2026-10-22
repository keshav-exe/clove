import SwiftUI

/// Where a skill installed from skills.sh came from, and whether it is current.
struct SkillOriginSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let entry: SkillLockEntry

    @State private var isEditedLocally = false

    private var manager: SkillManager { model.manager }

    var body: some View {
        SkillDetailSection(title: "From skills.sh") {
            VStack(alignment: .leading, spacing: Metrics.spacingS) {
                HStack(spacing: Metrics.spacingS) {
                    Button(entry.source, action: openListing)
                        .buttonStyle(.link)
                        .help("Open on skills.sh")
                    if let updated = entry.updatedAt {
                        Text("Updated \(updated, format: .relative(presentation: .named))")
                            .foregroundStyle(.secondary)
                    }
                }

                if isEditedLocally {
                    Label("Edited on this Mac. Updating replaces your edits.", systemImage: "pencil")
                        .foregroundStyle(.secondary)
                }

                SkillUpdateRow(name: entry.name)
            }
            .font(.callout)
        }
        .task(id: "\(entry.name)#\(manager.revision)") {
            isEditedLocally = await manager.isEditedLocally(entry.name)
        }
    }

    private func openListing() {
        openURL(entry.marketplaceSkill.pageURL)
    }
}
