import SwiftUI

struct OnboardingPermissionsStep: View {
    @State private var accessibilityGranted = AccessibilityAccess.isGranted

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(AppPermission.all) { permission in
                PermissionRow(
                    permission: permission,
                    isGranted: permission.isRequired ? accessibilityGranted : nil
                )
            }

            Divider()
                .padding(.top, 2)

            accessibilityAction
        }
        .onAppear {
            if !accessibilityGranted {
                AccessibilityAccess.requestPrompt()
            }
        }
    }

    @ViewBuilder
    private var accessibilityAction: some View {
        if accessibilityGranted {
            Label("Accessibility is on. Insert and drag will work everywhere.", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
        } else {
            HStack(spacing: 10) {
                Text("Turn on Accessibility to enable insert and drag.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Button("Check Again") {
                    accessibilityGranted = AccessibilityAccess.isGranted
                }
                .controlSize(.small)

                Button("Open Settings…") {
                    AccessibilityAccess.openSettings()
                }
                .controlSize(.small)
            }
        }
    }
}
