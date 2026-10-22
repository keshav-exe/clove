import SwiftUI

struct RunningArt: View {
    var body: some View {
        MockStack {
            MockProcessCard(name: "playwright", detail: "from Claude Code · 12 min")
        } middle: {
            MockProcessCard(name: "next dev", detail: "my-app · from Codex", port: ":3000")
        } front: {
            MockProcessCard(name: "Claude Code", detail: "my-app · 2 hr · 410 MB")
        }
    }
}
