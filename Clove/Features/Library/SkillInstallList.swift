import SwiftUI

struct SkillInstallList: View {
    let entry: CatalogEntry

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entry.copies) { copy in
                if copy.id != entry.copies.first?.id {
                    Divider()
                        .opacity(0.45)
                }

                SkillInstallRow(skill: copy)
            }
        }
    }
}
