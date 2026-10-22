import SwiftUI

struct LastUsedText: View {
    let date: Date?

    var body: some View {
        if let date {
            Text("Last used \(date, format: .relative(presentation: .named))")
        } else {
            Text("Never used")
        }
    }
}
