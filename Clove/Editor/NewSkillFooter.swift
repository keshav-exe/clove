import SwiftUI

struct NewSkillFooter: View {
    let failure: ManagerFailure?
    let isCreating: Bool
    let canCreate: Bool
    let cancel: () -> Void
    let create: () -> Void

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            if let failure {
                Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button("Cancel", role: .cancel, action: cancel)
                .keyboardShortcut(.cancelAction)
            Button("Create Skill", action: create)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate || isCreating)
        }
        .padding(Metrics.spacingL)
    }
}
