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
    var librarySelection: Skill.ID?

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

    /// Flattened section order, so arrow keys walk the rows in the order they
    /// are drawn rather than in raw search-rank order.
    var visibleSkills: [Skill] {
        sections.flatMap(\.skills)
    }

    var sections: [SkillSection] {
        SkillSearch.sections(from: rankedSkills)
    }

    private var rankedSkills: [Skill] {
        SkillSearch.results(
            skills: skills,
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

    var libraryResults: [Skill] {
        SkillSearch.library(
            skills: skills,
            query: libraryQuery,
            userTags: userTags,
            filter: libraryFilter
        )
    }

    var librarySelectedSkill: Skill? {
        skills.first { $0.id == librarySelection }
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
        var collected: [String] = []
        for skill in skills {
            for tag in tags(for: skill) {
                if !collected.contains(where: { $0.localizedStandardCompare(tag) == .orderedSame }) {
                    collected.append(tag)
                }
            }
        }
        return collected.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var tagsFileURL: URL {
        persistence.fileURL
    }

    func count(of filter: LibraryFilter) -> Int {
        SkillSearch.count(of: filter, in: skills, userTags: userTags)
    }

    func tags(for skill: Skill) -> [String] {
        SkillSearch.mergedTags(for: skill, userTags: userTags)
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
        selectedIDs = selectedIDs.filter { id in skills.contains { $0.id == id } }
        if let selectionAnchorID, !skills.contains(where: { $0.id == selectionAnchorID }) {
            self.selectionAnchorID = nil
        }
        if let librarySelection, !skills.contains(where: { $0.id == librarySelection }) {
            self.librarySelection = nil
        }
        if case .source(let source) = libraryFilter, !availableSources.contains(source) {
            libraryFilter = .all
        }
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
        guard activeTag != nil else { return }
        let references = visibleSkills.map(\.reference)
        guard !references.isEmpty else { return }
        copy(references.joined(separator: " "))
    }

    func copyReferences(for skills: [Skill]) {
        let references = skills.map(\.reference)
        guard !references.isEmpty else { return }
        copy(references.joined(separator: " "))
    }

    // MARK: - Insert (context menu only)

    func insert(_ skill: Skill) {
        let window = WindowBridge.shared.panelWindow?.isKeyWindow == true
            ? WindowBridge.shared.panelWindow
            : NSApp.keyWindow
        SkillInserter.insert(skill.reference, resigningFrom: window)
    }

    func insertSelected() {
        guard let skill = selectedSkill else { return }
        insert(skill)
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

    // MARK: - Tags

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
