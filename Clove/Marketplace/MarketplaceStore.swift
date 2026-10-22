import Foundation
import Observation

/// Browsing state for skills.sh. Nothing is fetched until Discover is opened.
@MainActor
@Observable
final class MarketplaceStore {
    private(set) var feeds: [DiscoverFeed: Loadable<[MarketplaceSkill]>] = [:]
    private(set) var searchResults: Loadable<[MarketplaceSkill]> = .idle
    private(set) var details: [MarketplaceSkill.ID: Loadable<MarketplaceDetail>] = [:]

    var feed: DiscoverFeed = .top
    var selection: MarketplaceSkill.ID?
    var query = "" {
        didSet { scheduleSearch() }
    }

    /// Every listing seen this session, so the selection survives switching feeds.
    private var known: [MarketplaceSkill.ID: MarketplaceSkill] = [:]
    private var loadedAt: [DiscoverFeed: Date] = [:]
    private var searchTask: Task<Void, Never>?
    private let client: SkillsDirectoryClient

    /// Leaderboards move slowly; refetch at most this often unless asked.
    private let feedLifetime: TimeInterval = 600

    init(client: SkillsDirectoryClient = SkillsDirectoryClient()) {
        self.client = client
    }

    var isSearching: Bool {
        query.trimmingCharacters(in: .whitespaces).count >= 2
    }

    /// The list on screen: search results while searching, else the feed.
    var visible: Loadable<[MarketplaceSkill]> {
        isSearching ? searchResults : (feeds[feed] ?? .idle)
    }

    var selectedSkill: MarketplaceSkill? {
        selection.flatMap { known[$0] }
    }

    func skill(withID id: MarketplaceSkill.ID) -> MarketplaceSkill? {
        known[id]
    }

    // MARK: - Feeds

    func loadFeed(_ feed: DiscoverFeed, force: Bool = false) async {
        if !force, let loaded = loadedAt[feed], feeds[feed]?.value != nil,
           Date.now.timeIntervalSince(loaded) < feedLifetime {
            return
        }
        if feeds[feed]?.isLoading == true { return }

        if feeds[feed]?.value == nil {
            feeds[feed] = .loading
        }
        do {
            let skills = try await client.leaderboard(feed)
            remember(skills)
            feeds[feed] = .loaded(skills)
            loadedAt[feed] = .now
        } catch {
            if feeds[feed]?.value == nil {
                feeds[feed] = .failed(Self.message(for: error))
            }
        }
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else {
            searchResults = .idle
            return
        }

        if searchResults.value == nil {
            searchResults = .loading
        }
        searchTask = Task { [weak self, client] in
            // Wait for typing to settle before hitting the network.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                let results = try await client.search(text)
                guard !Task.isCancelled else { return }
                self?.remember(results)
                self?.searchResults = .loaded(results)
            } catch {
                guard !Task.isCancelled else { return }
                self?.searchResults = .failed(Self.message(for: error))
            }
        }
    }

    // MARK: - Detail

    func loadDetail(for skill: MarketplaceSkill, force: Bool = false) async {
        if !force, details[skill.id]?.value != nil || details[skill.id]?.isLoading == true {
            return
        }
        details[skill.id] = .loading

        async let page = try? client.pageDetails(for: skill)
        async let file = try? client.skillFile(for: skill)
        let (pageResult, fileResult) = await (page, file)

        guard pageResult != nil || fileResult != nil else {
            details[skill.id] = .failed("Couldn't load this skill. Check your connection and try again.")
            return
        }
        details[skill.id] = .loaded(await Self.makeDetail(page: pageResult, file: fileResult))
    }

    /// Parsing the markdown happens off the main actor.
    @concurrent
    private static func makeDetail(page: SkillPageDetails?, file: RemoteSkillFile?) async -> MarketplaceDetail {
        MarketplaceDetail(page: page, file: file)
    }

    private func remember(_ skills: [MarketplaceSkill]) {
        for skill in skills {
            known[skill.id] = skill
        }
    }

    private static func message(for error: any Error) -> String {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            return "You're offline. Discover needs a connection to skills.sh."
        }
        if let described = (error as? LocalizedError)?.errorDescription {
            return described
        }
        return "skills.sh couldn't be reached. Try again in a moment."
    }
}
