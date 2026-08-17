import SwiftUI

struct PermissionRow: View {
    let permission: AppPermission
    var isGranted: Bool?

    var body: some View {
        OnboardingRow(
            systemImage: permission.symbolName,
            title: permission.title,
            detail: permission.detail,
            badge: permission.isRequired ? "Required" : nil
        ) {
            if let isGranted {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isGranted ? Color.green : Color.orange)
                    .accessibilityLabel(isGranted ? "Enabled" : "Not enabled yet")
            }
        }
    }
}
