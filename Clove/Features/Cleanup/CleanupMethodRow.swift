import SwiftUI

struct CleanupMethodRow: View {
    let symbolName: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)
        }
        .font(.callout)
    }
}
