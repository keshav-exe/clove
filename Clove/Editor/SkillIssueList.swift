import SwiftUI

struct SkillIssueList: View {
    let issues: [SkillDocumentIssue]

    var body: some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(issues) { issue in
                    Label {
                        Text(issue.message)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(issue.severity == .error ? .red : .orange)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
