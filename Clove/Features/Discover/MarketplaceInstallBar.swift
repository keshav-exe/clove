import SwiftUI

/// Floats over the scrolling SKILL.md, so install is always one click away.
struct MarketplaceInstallBar: View {
    @Environment(AppModel.self) private var model
    let skill: MarketplaceSkill
    /// Folder of SKILL.md in the repo, once the detail has found it.
    let folderHint: String?

    @State private var didCopyCommand = false
    /// Nil installs everywhere; a folder installs into that project only.
    @State private var project: URL?

    private var manager: SkillManager { model.manager }

    var body: some View {
        GlassEffectContainer(spacing: Metrics.spacingS) {
            HStack(spacing: Metrics.spacingS) {
                if let phase = manager.phase(for: skill.skillId) {
                    MarketplaceInstallProgress(phase: phase)
                } else {
                    if manager.hasUpdate(skill.skillId), project == nil {
                        Button("Update", systemImage: "arrow.down.circle", action: update)
                            .buttonStyle(.glassProminent)
                    } else if model.isInstalled(skill), project == nil {
                        Button("Show in Library", systemImage: "checkmark.circle.fill", action: showInLibrary)
                            .buttonStyle(.glass)
                    } else {
                        Button(installTitle, systemImage: "arrow.down", action: install)
                            .buttonStyle(.glassProminent)
                            .disabled(!skill.isGitHub || manager.defaultTargets.isEmpty)
                            .help(skill.isGitHub ? "Install for \(targetSummary)" : "Only skills hosted on GitHub install from Clove")
                    }

                    InstallOptionsMenu(targets: targetsBinding, project: $project)
                }

                Button(
                    didCopyCommand ? "Copied" : "Copy Command",
                    systemImage: didCopyCommand ? "checkmark" : "terminal",
                    action: copyCommand
                )
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .help("Copy “\(skill.installCommand)”")
            }
            .controlSize(.large)
        }
        .padding(Metrics.spacingL)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.success, trigger: didCopyCommand) { _, copied in copied }
        .task(id: didCopyCommand) {
            guard didCopyCommand else { return }
            try? await Task.sleep(for: .seconds(1.5))
            didCopyCommand = false
        }
    }

    private var targetSummary: String {
        AgentTarget.allCases
            .filter(manager.defaultTargets.contains)
            .map(\.title)
            .formatted(.list(type: .and))
    }

    private var targetsBinding: Binding<Set<AgentTarget>> {
        Binding {
            manager.defaultTargets
        } set: { targets in
            manager.defaultTargets = targets
        }
    }

    private var installTitle: String {
        project.map { "Install in \($0.lastPathComponent)" } ?? "Install"
    }

    private func install() {
        let request = PendingInstall(skill: skill, folderHint: folderHint, targets: manager.defaultTargets, project: project)
        Task { await manager.install(request) }
    }

    private func update() {
        Task { await manager.update(skill.skillId) }
    }

    private func showInLibrary() {
        model.showInLibrary(skill)
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(skill.installCommand, forType: .string)
        didCopyCommand = true
    }
}
