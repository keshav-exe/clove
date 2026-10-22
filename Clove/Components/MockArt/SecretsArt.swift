import SwiftUI

struct SecretsArt: View {
    var body: some View {
        MockStack {
            MockKeyCard(name: "GITHUB_TOKEN")
        } middle: {
            MockKeyCard(name: "FIGMA_API_KEY")
        } front: {
            MockKeyCard(name: "OPENAI_API_KEY")
        }
    }
}
