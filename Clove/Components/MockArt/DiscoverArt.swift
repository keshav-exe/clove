import SwiftUI

struct DiscoverArt: View {
    var body: some View {
        MockStack {
            MockListingCard(name: "frontend-design", owner: "anthropics/skills", installs: "1M")
        } middle: {
            MockListingCard(name: "agent-browser", owner: "vercel-labs/agent-browser", installs: "1.2M")
        } front: {
            MockListingCard(name: "swiftui-pro", owner: "twostraws/swiftui-agent-skill", installs: "34K")
        }
    }
}
