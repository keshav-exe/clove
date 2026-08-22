import SwiftUI

struct OnboardingPermissionsStep: View {
    @State private var accessibilityGranted = AccessibilityAccess.isGranted

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(AppPermission.all) { permission in
                        permissionRow(permission)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)

            accessibilityAction
        }
        .onAppear {
            if !accessibilityGranted {
                AccessibilityAccess.requestPrompt()
            }
        }
    }

    @ViewBuilder
    private func permissionRow(_ permission: AppPermission) -> some View {
        HStack(alignment: .top, spacing: 12) {
            FeatureHighlightRow(
                highlight: FeatureHighlight(
                    symbolName: permission.symbolName,
                    title: permission.title,
                    detail: permission.detail
                )
            )

            if permission.isRequired {
                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accessibilityGranted ? .green : .orange)
                    .padding(.top, 4)
                    .accessibilityLabel(accessibilityGranted ? "Enabled" : "Not enabled yet")
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
            HStack {
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
