import SwiftUI

struct OnboardingWelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingRow(
                systemImage: "magnifyingglass",
                title: "Search everything at once",
                detail: "Names, descriptions, and tags across Cursor, Claude, Codex, Agents, plugins, and projects."
            )

            OnboardingRow(
                systemImage: "pin",
                title: "Pin it beside your editor",
                detail: "The quick access panel floats above other apps so your list stays in view while you work."
            )

            OnboardingRow(
                systemImage: "tag",
                title: "Tag skills your way",
                detail: "Group the skills that belong together. Your tags are saved on this Mac."
            )

            OnboardingRow(
                systemImage: "feather",
                title: "Light on your Mac",
                detail: "A few megabytes of native Swift. No Electron, no background daemon, no login item unless you ask."
            )
        }
    }
}
