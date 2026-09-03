import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var skills: [Skill] = []
    var isScanning = false
    var didScan = false
    var userTags: [String: [String]] = [:]

    /// Quick-access panel state.
    var query = ""
    var selectedIDs: Set<Skill.ID> = []
    var selectionAnchorID: Skill.ID?
    var activeTag: String?
    var footerText = ""
    var displayTick = 0
    var activeFocus: PanelFocus?
    var focusTarget: PanelFocus = .search
    var focusTick = 0

    /// Main window state, kept separate so the window and the panel never fight
    /// over the same search field.
    var libraryQuery = ""
    var libraryFilter: LibraryFilter = .all
    var librarySelection: CatalogEntry.ID?

    let settings: SettingsStore
    private let scanner: SkillScanner
    private let persistence: TagPersistence

    init(
        settings: SettingsStore = SettingsStore(),
        scanner: SkillScanner = SkillScanner(),
        persistence: TagPersistence = TagPersistence(fileURL: TagPersistence.defaultFile)
    ) {
        self.settings = settings
        self.scanner = scanner
        self.persistence = persistence
        userTags = persistence.load()
    }

    // MARK: - Derived data

    var catalog: [CatalogEntry] {
        SkillCatalog.build(from: skills)
    }

    /// Flattened section order, so arrow keys walk the rows in the order they
    /// are drawn rather than in raw search-rank order.
    var visibleSkills: [Skill] {
        rankedCatalog.map(\.primary)
    }

    var sections: [SkillSection] {
        SkillSearch.sections(from: rankedCatalog)
    }

    private var rankedCatalog: [CatalogEntry] {
        SkillSearch.results(
            catalog: catalog,
            query: query,
            userTags: userTags,
            activeTag: activeTag
        )
    }

    var selectedSkills: [Skill] {
        visibleSkills.filter { selectedIDs.contains($0.id) }
    }

    var selectedSkill: Skill? {
        selectedSkills.last ?? selectedSkills.first
    }

    var libraryResults: [CatalogEntry] {
        SkillSearch.library(
            catalog: catalog,
            query: libraryQuery,
            userTags: userTags,
            filter: libraryFilter
        )
    }

    var librarySelectedEntry: CatalogEntry? {
        guard let librarySelection else { return nil }
        return catalog.first { $0.id == librarySelection }
    }

    var librarySelectedSkill: Skill? {
        librarySelectedEntry?.primary
    }

    var sidebarSelection: LibraryFilter? {
        get { libraryFilter }
        set { libraryFilter = newValue ?? .all }
    }

    var availableSources: [SkillSource] {
        var seen: [SkillSource] = []
        for skill in skills where !seen.contains(skill.source) {
            seen.append(skill.source)
        }
        return seen.sorted()
    }

    var allUserFacingTags: [String] {
        allGroups
    }

    var allGroups: [String] {
        var collected = settings.savedGroupNames
        for entry in catalog {
            for tag in tags(for: entry) {
                if !collected.contains(where: { $0.localizedStandardCompare(tag) == .orderedSame }) {
                    collected.append(tag)
                }
            }
        }
        return collected.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var pinnedGroups: [String] {
        settings.pinnedGroups.filter { name in
            allGroups.contains { $0.localizedStandardCompare(name) == .orderedSame }
        }
    }

    var tagsFileURL: URL {
        persistence.fileURL
    }

    func count(of filter: LibraryFilter) -> Int {
        SkillSearch.count(of: filter, in: catalog, userTags: userTags)
    }

    func tags(for entry: CatalogEntry) -> [String] {
        SkillSearch.mergedTags(for: entry, userTags: userTags)
    }

    func tags(for skill: Skill) -> [String] {
        if let entry = SkillCatalog.entry(for: skill, in: catalog) {
            return tags(for: entry)
        }
        return SkillSearch.mergedTags(for: skill, userTags: userTags)
    }

    func isUserTag(_ tag: String, for entry: CatalogEntry) -> Bool {
        entry.copies.contains { skill in
            (userTags[skill.id] ?? []).contains { $0.localizedStandardCompare(tag) == .orderedSame }
        }
    }

    func isUserTag(_ tag: String, for skill: Skill) -> Bool {
        (userTags[skill.id] ?? []).contains { $0.localizedStandardCompare(tag) == .orderedSame }
    }

    func isSelected(_ skill: Skill) -> Bool {
        selectedIDs.contains(skill.id)
    }

    // MARK: - Scanning

    /// No skill file is opened until the user has been through setup, so the
    /// library cannot show results the user never agreed to have scanned.
    func startIfNeeded() async {
        guard settings.hasCompletedOnboarding else { return }
        guard !didScan else { return }
        await refresh()
    }

    func refresh() async {
        isScanning = true
        defer { isScanning = false }
        skills = await scanner.scan(configuration: settings.scanConfiguration)
        didScan = true
        remapSelectionsAfterScan()
    }

    func prepareForDisplay() {
        displayTick += 1
        // Something is always selected, so Return works the moment the panel opens.
        ensureSelectionVisible()
    }

    // MARK: - Panel focus
    //
    // The key router runs outside SwiftUI, so focus moves are requested through
    // the model and applied by the panel's `@FocusState`.

    func requestFocus(_ target: PanelFocus) {
        focusTarget = target
        focusTick += 1
    }

    // MARK: - Panel selection

    func select(_ skill: Skill, modifiers: NSEvent.ModifierFlags = []) {
        if modifiers.contains(.command) {
            toggleSelection(skill)
            return
        }
        if modifiers.contains(.shift) {
            extendSelection(to: skill)
            return
        }
        selectExclusive(skill)
    }

    func selectExclusive(_ skill: Skill) {
        selectedIDs = [skill.id]
        selectionAnchorID = skill.id
    }

    func toggleSelection(_ skill: Skill) {
        if selectedIDs.contains(skill.id) {
            selectedIDs.remove(skill.id)
        } else {
            selectedIDs.insert(skill.id)
        }
        selectionAnchorID = skill.id
    }

    func extendSelection(to skill: Skill) {
        let anchor = selectionAnchorID
            ?? selectedIDs.first
            ?? visibleSkills.first?.id

        guard
            let anchor,
            let anchorIndex = visibleSkills.firstIndex(where: { $0.id == anchor }),
            let targetIndex = visibleSkills.firstIndex(where: { $0.id == skill.id })
        else {
            selectExclusive(skill)
            return
        }

        let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        selectedIDs = Set(visibleSkills[range].map(\.id))
        selectionAnchorID = anchor
    }

    func selectNext(extending: Bool = false) {
        moveSelection(by: 1, extending: extending)
    }

    func selectPrevious(extending: Bool = false) {
        moveSelection(by: -1, extending: extending)
    }

    func selectFirst() {
        guard let first = visibleSkills.first else { return }
        selectExclusive(first)
    }

    func selectLast() {
        guard let last = visibleSkills.last else { return }
        selectExclusive(last)
    }

    func selectAllVisible() {
        let items = visibleSkills
        guard !items.isEmpty else { return }
        selectedIDs = Set(items.map(\.id))
        selectionAnchorID = items.first?.id
    }

    func clearQuery() {
        query = ""
    }

    func ensureSelectionVisible() {
        selectedIDs = selectedIDs.filter { id in visibleSkills.contains { $0.id == id } }
        guard selectedIDs.isEmpty, let first = visibleSkills.first?.id else { return }
        selectedIDs = [first]
        selectionAnchorID = first
    }

    // MARK: - Copy

    func copySelectedReferences() {
        let references = selectedSkills.map(\.reference)
        guard !references.isEmpty else { return }
        copy(references.joined(separator: " "))
    }

    func copyActiveTagGroup() {
        guard let activeTag else { return }
        copyGroup(activeTag)
    }

    func copySelectedSkillGroup() {
        if let activeTag {
            copyGroup(activeTag)
            return
        }
        guard let skill = selectedSkill else { return }
        let groups = tags(for: skill)
        guard let first = groups.first else { return }
        copyGroup(first)
    }

    func copyGroup(_ name: String) {
        let references = skills(inGroup: name).map(\.reference)
        guard !references.isEmpty else { return }
        copy(references.joined(separator: " "))
    }

    func skills(inGroup name: String) -> [Skill] {
        catalog.filter { entry in
            tags(for: entry).contains { $0.localizedStandardCompare(name) == .orderedSame }
        }
        .map(\.primary)
    }

    private func remapSelectionsAfterScan() {
        let built = catalog

        func catalogID(for skillID: String) -> String? {
            built.first { $0.copies.contains { $0.id == skillID } }?.id
        }

        func primaryID(for skillID: String) -> String? {
            built.first { $0.copies.contains { $0.id == skillID } }?.primary.id
        }

        selectedIDs = Set(selectedIDs.compactMap { primaryID(for: $0) })

        if let selectionAnchorID {
            self.selectionAnchorID = primaryID(for: selectionAnchorID)
        }

        if let librarySelection {
            self.librarySelection = catalogID(for: librarySelection) ?? librarySelection
            if built.contains(where: { $0.id == self.librarySelection }) == false {
                self.librarySelection = nil
            }
        }

        if case .source(let source) = libraryFilter, !availableSources.contains(source) {
            libraryFilter = .all
        }
    }

    func copyReferences(for skills: [Skill]) {
        let references = skills.map(\.reference)
        guard !references.isEmpty else { return }
        copy(references.joined(separator: " "))
    }

    // MARK: - Insert

    /// Return types the highlighted skill into the app you came from.
    /// Option keeps the panel open and only copies, so you can grab another.
    func confirmPanelSelection(option: Bool, command: Bool, dismiss: () -> Void) {
        guard !selectedSkills.isEmpty else { return }
        if option, !command {
            copySelectedReferences()
            return
        }
        dismiss()
        insertSelected()
    }

    func insert(_ skill: Skill) {
        insertReferences([skill.reference])
    }

    func insertSelected() {
        insertReferences(selectedSkills.map(\.reference))
    }

    private func insertReferences(_ references: [String]) {
        let text = references.joined(separator: " ")
        guard !text.isEmpty else { return }
        let window = WindowBridge.shared.panelWindow?.isKeyWindow == true
            ? WindowBridge.shared.panelWindow
            : NSApp.keyWindow
        SkillInserter.insert(text, resigningFrom: window)
    }

    // MARK: - File actions

    func open(_ skill: Skill) {
        NSWorkspace.shared.open(skill.fileURL)
    }

    func reveal(_ skill: Skill) {
        NSWorkspace.shared.activateFileViewerSelecting([skill.originalURL])
    }

    func copyReference(_ skill: Skill) {
        copy(skill.reference)
    }

    func copyPath(_ skill: Skill) {
        copyReference(skill)
    }

    func copyName(_ skill: Skill) {
        copy(skill.displayName)
    }

    // MARK: - Groups

    func toggleTagFilter(_ tag: String) {
        if let activeTag, activeTag.localizedStandardCompare(tag) == .orderedSame {
            self.activeTag = nil
        } else {
            activeTag = tag
        }
    }

    func clearTagFilter() {
        activeTag = nil
    }

    func createGroup(named raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !allGroups.contains(where: { $0.localizedStandardCompare(name) == .orderedSame }) else { return }
        settings.savedGroupNames.append(name)
    }

    func deleteGroup(_ name: String) {
        settings.savedGroupNames.removeAll { $0.localizedStandardCompare(name) == .orderedSame }
        for skill in skills where isUserTag(name, for: skill) {
            removeTag(name, from: skill)
        }
        for skill in skills where skill.frontmatterTags.contains(where: { $0.localizedStandardCompare(name) == .orderedSame }) {
            // Frontmatter groups can't be removed, but drop the saved name entry.
            break
        }
        unpinGroup(name)
        dropFilters(forRemoved: name)
    }

    func renameGroup(from oldName: String, to raw: String) {
        let newName = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        guard newName.localizedStandardCompare(oldName) != .orderedSame else { return }
        guard !allGroups.contains(where: { $0.localizedStandardCompare(newName) == .orderedSame }) else { return }

        if let index = settings.savedGroupNames.firstIndex(where: { $0.localizedStandardCompare(oldName) == .orderedSame }) {
            settings.savedGroupNames[index] = newName
        } else {
            settings.savedGroupNames.append(newName)
        }

        for skill in skills where isUserTag(oldName, for: skill) {
            removeTag(oldName, from: skill)
            addTag(newName, to: skill)
        }

        if let activeTag, activeTag.localizedStandardCompare(oldName) == .orderedSame {
            self.activeTag = newName
        }
        if case .tag(let filtered) = libraryFilter, filtered.localizedStandardCompare(oldName) == .orderedSame {
            libraryFilter = .tag(newName)
        }
        if let index = settings.pinnedGroups.firstIndex(where: { $0.localizedStandardCompare(oldName) == .orderedSame }) {
            settings.pinnedGroups[index] = newName
        }
    }

    func isGroupPinned(_ name: String) -> Bool {
        settings.pinnedGroups.contains { $0.localizedStandardCompare(name) == .orderedSame }
    }

    func togglePinGroup(_ name: String) {
        if isGroupPinned(name) {
            unpinGroup(name)
        } else {
            settings.pinnedGroups.append(name)
        }
    }

    func unpinGroup(_ name: String) {
        settings.pinnedGroups.removeAll { $0.localizedStandardCompare(name) == .orderedSame }
    }

    func cyclePinnedGroup() {
        let groups = pinnedGroups
        guard !groups.isEmpty else { return }

        if let activeTag,
           let index = groups.firstIndex(where: { $0.localizedStandardCompare(activeTag) == .orderedSame }) {
            let next = groups[(index + 1) % groups.count]
            self.activeTag = next
        } else {
            activeTag = groups[0]
        }
    }

    func addSkillToGroup(_ skill: Skill, group name: String) {
        addTag(name, to: skill)
        ensureGroupExists(name)
    }

    func addSelectedSkillsToGroup(_ name: String) {
        for skill in selectedSkills {
            addTag(name, to: skill)
        }
        ensureGroupExists(name)
    }

    func addLibrarySelectionToGroup(_ name: String) {
        guard let skill = librarySelectedSkill else { return }
        addSkillToGroup(skill, group: name)
    }

    private func ensureGroupExists(_ name: String) {
        guard !settings.savedGroupNames.contains(where: { $0.localizedStandardCompare(name) == .orderedSame }) else {
            return
        }
        settings.savedGroupNames.append(name)
    }

    func addFooterTag() {
        guard let selectedSkill else { return }
        addTag(footerText, to: selectedSkill)
        footerText = ""
    }

    func addTag(_ raw: String, to skill: Skill) {
        let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        var tags = userTags[skill.id] ?? []
        if tags.contains(where: { $0.localizedStandardCompare(tag) == .orderedSame }) {
            return
        }
        tags.append(tag)
        userTags[skill.id] = tags
        persistence.save(userTags)
        ensureGroupExists(tag)
    }

    func removeTag(_ tag: String, from skill: Skill) {
        guard var tags = userTags[skill.id] else { return }
        tags.removeAll { $0.localizedStandardCompare(tag) == .orderedSame }
        userTags[skill.id] = tags.isEmpty ? nil : tags
        persistence.save(userTags)
        dropFilters(forRemoved: tag)
    }

    func resetLocalTags() {
        userTags = [:]
        persistence.save(userTags)
        settings.savedGroupNames = []
        settings.pinnedGroups = []
        activeTag = nil
        libraryFilter = .all
    }

    // MARK: - App

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func dropFilters(forRemoved tag: String) {
        let stillUsed = allUserFacingTags.contains { $0.localizedStandardCompare(tag) == .orderedSame }
        guard !stillUsed else { return }
        if let activeTag, activeTag.localizedStandardCompare(tag) == .orderedSame {
            self.activeTag = nil
        }
        if case .tag(let filtered) = libraryFilter, filtered.localizedStandardCompare(tag) == .orderedSame {
            libraryFilter = .all
        }
    }

    private func moveSelection(by offset: Int, extending: Bool) {
        let items = visibleSkills
        guard !items.isEmpty else { return }

        if extending {
            let anchor = selectionAnchorID ?? selectedIDs.first ?? items.first?.id
            guard
                let anchor,
                let anchorIndex = items.firstIndex(where: { $0.id == anchor })
            else { return }

            let focusIndex: Int
            if let lastSelected = selectedSkills.last?.id,
               let index = items.firstIndex(where: { $0.id == lastSelected }) {
                focusIndex = index
            } else {
                focusIndex = anchorIndex
            }

            let next = min(max(focusIndex + offset, 0), items.count - 1)
            let range = min(anchorIndex, next)...max(anchorIndex, next)
            selectedIDs = Set(items[range].map(\.id))
            selectionAnchorID = anchor
            return
        }

        let focusIndex: Int
        if let lastSelected = selectedSkills.last?.id,
           let index = items.firstIndex(where: { $0.id == lastSelected }) {
            focusIndex = index
        } else {
            focusIndex = offset >= 0 ? 0 : items.count - 1
        }

        let next = min(max(focusIndex + offset, 0), items.count - 1)
        let skill = items[next]
        selectedIDs = [skill.id]
        selectionAnchorID = skill.id
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

extension AppModel {
    static var preview: AppModel {
        let model = AppModel(
            persistence: TagPersistence(
                fileURL: URL.temporaryDirectory.appending(path: "clove-preview-tags.json")
            )
        )
        model.didScan = true
        model.skills = [
            Skill(
                name: "swiftui-pro",
                summary: "Review Swift and SwiftUI code for correctness and modern API usage.",
                originalURL: URL(filePath: "/tmp/swiftui-pro/SKILL.md"),
                fileURL: URL(filePath: "/tmp/swiftui-pro/SKILL.md"),
                resolvedPath: "/tmp/swiftui-pro/SKILL.md",
                directoryName: "swiftui-pro",
                source: .claude,
                sourceDetail: nil,
                frontmatterTags: ["swiftui"],
                modifiedAt: .now,
                isSymlink: false,
                installKind: .homeLocal
            ),
            Skill(
                name: "create-skill",
                summary: "Create Cursor Agent Skills. Use when authoring a new skill.",
                originalURL: URL(filePath: "/tmp/create-skill/SKILL.md"),
                fileURL: URL(filePath: "/tmp/create-skill/SKILL.md"),
                resolvedPath: "/tmp/create-skill/SKILL.md",
                directoryName: "create-skill",
                source: .cursorBuiltin,
                sourceDetail: nil,
                frontmatterTags: [],
                modifiedAt: .now,
                isSymlink: false,
                installKind: .homeLocal
            ),
            Skill(
                name: "nextjs",
                summary: "Next.js App Router expert guidance for building production apps.",
                originalURL: URL(filePath: "/tmp/nextjs/SKILL.md"),
                fileURL: URL(filePath: "/tmp/nextjs/SKILL.md"),
                resolvedPath: "/tmp/nextjs/SKILL.md",
                directoryName: "nextjs",
                source: .plugin,
                sourceDetail: "vercel",
                frontmatterTags: ["next"],
                modifiedAt: .now,
                isSymlink: false,
                installKind: .plugin
            ),
        ]
        model.userTags = ["/tmp/create-skill/SKILL.md": ["authoring"]]
        return model
    }
}
