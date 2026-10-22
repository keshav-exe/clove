import Foundation
import Observation

/// Installs, updates, links, and removes skills, and reports progress to the UI.
@MainActor
@Observable
final class SkillManager {
    enum Phase: Equatable, Sendable {
        case installing
        case updating
        case removing
    }

    private(set) var lockEntries: [String: SkillLockEntry] = [:]
    /// Work in progress, keyed by skill folder name.
    private(set) var phases: [String: Phase] = [:]
    private(set) var updatesAvailable: Set<String> = []
    private(set) var isCheckingUpdates = false
    private(set) var lastUpdateCheck: Date?
    var failure: ManagerFailure?
    /// An install that would replace an unrelated skill, waiting for confirmation.
    var pendingConflict: PendingInstall?

    let installer: SkillInstaller
    private let settings: SettingsStore
    /// Rescans the library after anything on disk changes.
    var didChangeFiles: () async -> Void = {}
    /// Bumped after every change on disk, so views can reload what they read.
    private(set) var revision = 0

    init(settings: SettingsStore, installer: SkillInstaller = SkillInstaller()) {
        self.settings = settings
        self.installer = installer
        reloadLock()
    }

    func reloadLock() {
        lockEntries = installer.lock.entries()
    }

    func phase(for name: String) -> Phase? {
        phases[name]
    }

    func hasUpdate(_ name: String) -> Bool {
        updatesAvailable.contains(name)
    }

    // MARK: - Install

    func install(_ install: PendingInstall, replacingConflict: Bool = false) async {
        let name = install.skill.skillId
        guard phases[name] == nil else { return }
        phases[name] = lockEntries[name] == nil ? .installing : .updating
        defer { phases[name] = nil }

        do {
            try await installer.install(
                install.skill,
                folderHint: install.folderHint,
                targets: install.targets,
                replacingConflict: replacingConflict
            )
            updatesAvailable.remove(name)
            reloadLock()
            await filesChanged()
        } catch SkillInstaller.Failure.conflict {
            pendingConflict = install
        } catch {
            failure = ManagerFailure(title: "Couldn't install \(name)", error: error)
        }
    }

    func confirmPendingConflict() async {
        guard let pending = pendingConflict else { return }
        pendingConflict = nil
        await install(pending, replacingConflict: true)
    }

    // MARK: - Create

    /// Writes a new skill and rescans. Failures go back to the builder,
    /// which shows them in place rather than over the library.
    func create(_ document: SkillDocument, targets: Set<AgentTarget>) async -> Result<URL, ManagerFailure> {
        do {
            let file = try await installer.create(
                name: document.name,
                markdown: document.markdown,
                targets: targets
            )
            await filesChanged()
            return .success(file)
        } catch SkillInstaller.Failure.conflict(let name) {
            return .failure(ManagerFailure(
                title: "“\(name)” already exists",
                message: "Pick another name, or open the existing skill from the library."
            ))
        } catch {
            return .failure(ManagerFailure(title: "Couldn't create \(document.name)", error: error))
        }
    }

    // MARK: - Updates

    func checkForUpdates() async {
        guard !isCheckingUpdates else { return }
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        reloadLock()
        do {
            updatesAvailable = try await installer.entriesWithUpdates(Array(lockEntries.values))
            lastUpdateCheck = .now
        } catch {
            failure = ManagerFailure(title: "Couldn't check for updates", error: error)
        }
    }

    func update(_ name: String) async {
        guard let entry = lockEntries[name] else { return }
        let targets = await installer.linkedTargets(for: name)
        await install(PendingInstall(skill: entry.marketplaceSkill, folderHint: entry.folderPath, targets: targets))
    }

    func updateAll() async {
        for name in updatesAvailable.sorted() {
            await update(name)
        }
    }

    // MARK: - Linking

    func linkedTargets(for name: String) async -> Set<AgentTarget> {
        await installer.linkedTargets(for: name)
    }

    /// Whether `~/.agents/skills` holds this skill, so agents can link to it.
    func hasSharedCopy(_ name: String) -> Bool {
        let folder = installer.sharedFolder.appending(path: name)
        return FileManager.default.fileExists(atPath: folder.appending(path: "SKILL.md").path(percentEncoded: false))
    }

    func isEditedLocally(_ name: String) async -> Bool {
        guard let entry = lockEntries[name] else { return false }
        return await installer.isEditedLocally(entry)
    }

    /// Links the shared copy into an agent, or removes it from that agent.
    func setLinked(_ linked: Bool, name: String, target: AgentTarget) async {
        do {
            if linked {
                try await installer.link(name, to: target)
            } else {
                try await installer.unlink(name, from: target)
            }
            await filesChanged()
        } catch {
            failure = ManagerFailure(title: "Couldn't change \(target.title)", error: error)
        }
    }

    // MARK: - Remove

    /// Moves every copy in an agent home folder to the Trash. Plugin and
    /// project copies are left alone: they belong to something else.
    func uninstall(_ entry: CatalogEntry) async {
        await uninstall([entry])
    }

    /// Removes several skills with one rescan. Returns a receipt for undo,
    /// or nil if nothing was removed.
    @discardableResult
    func uninstall(_ entries: [CatalogEntry]) async -> TrashReceipt? {
        var receipt = TrashReceipt()
        let names = entries.map(\.primary.directoryName)
        for name in names { phases[name] = .removing }
        defer { for name in names { phases[name] = nil } }

        for entry in entries {
            let name = entry.primary.directoryName
            let folders = entry.copies
                .filter(\.source.isAgentHome)
                .map { $0.originalURL.deletingLastPathComponent() }
            let shared = installer.sharedFolder.appending(path: name)
            do {
                receipt.append(try await installer.uninstall(folders: folders + [shared], name: name))
                updatesAvailable.remove(name)
            } catch {
                failure = ManagerFailure(title: "Couldn't remove \(name)", error: error)
                break
            }
        }

        reloadLock()
        await filesChanged()
        return receipt.moves.isEmpty && receipt.links.isEmpty ? nil : receipt
    }

    /// Moves one agent file, like a command or rule, to the Trash.
    func trash(_ file: URL) async {
        do {
            try FileManager.default.trashItem(at: file, resultingItemURL: nil)
            await filesChanged()
        } catch {
            failure = ManagerFailure(title: "Couldn't move \(file.lastPathComponent) to the Trash", error: error)
        }
    }

    /// Moves several files to the Trash with one rescan, returning what moved for undo.
    func trash(_ files: [URL]) async -> TrashReceipt? {
        var receipt = TrashReceipt()
        for file in files {
            var trashed: NSURL?
            do {
                try FileManager.default.trashItem(at: file, resultingItemURL: &trashed)
                if let trashed = trashed as URL? {
                    receipt.moves.append(.init(original: file, trashed: trashed))
                }
            } catch {
                failure = ManagerFailure(title: "Couldn't move \(file.lastPathComponent) to the Trash", error: error)
                break
            }
        }
        await filesChanged()
        return receipt.moves.isEmpty ? nil : receipt
    }

    func restore(_ receipt: TrashReceipt) async {
        do {
            try await installer.restore(receipt)
        } catch {
            failure = ManagerFailure(title: "Couldn't put the skills back", error: error)
        }
        reloadLock()
        await filesChanged()
    }

    private func filesChanged() async {
        revision += 1
        await didChangeFiles()
    }

    /// Remembers the agents chosen last time, like the `skills` CLI does.
    var defaultTargets: Set<AgentTarget> {
        get { settings.installTargets }
        set { settings.installTargets = newValue }
    }
}
