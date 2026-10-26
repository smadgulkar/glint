import Foundation
import Combine

struct ArchivedTab: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var url: URL
    var archivedAt: Date
}

@MainActor
final class TabStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published private(set) var archived: [ArchivedTab] = []
    @Published private(set) var activeID: UUID?
    @Published var showingHome = true

    var active: BrowserTab? { tabs.first { $0.id == activeID } }

    init() {
        restore()
    }

    // MARK: - Opening and closing

    @discardableResult
    func open(_ url: URL, inNewTab: Bool = true) -> BrowserTab {
        if !inNewTab, let current = active {
            current.load(url)
            select(current)
            return current
        }
        let tab = BrowserTab(title: "")
        tabs.insert(tab, at: 0)
        tab.load(url)
        select(tab)
        save()
        return tab
    }

    /// Adds tabs without loading them (used by Import). They load when opened.
    func addLazily(_ urls: [URL]) {
        for url in urls {
            tabs.append(BrowserTab(title: url.host() ?? url.absoluteString, url: url))
        }
        save()
    }

    func select(_ tab: BrowserTab) {
        activeID = tab.id
        tab.lastActive = .now
        showingHome = false
    }

    func goHome() {
        showingHome = true
    }

    func close(_ tab: BrowserTab) {
        tab.tearDown()
        tabs.removeAll { $0.id == tab.id }
        if activeID == tab.id {
            activeID = nil
            showingHome = true
        }
        save()
    }

    func closeAll() {
        for tab in tabs { tab.tearDown() }
        tabs.removeAll()
        activeID = nil
        showingHome = true
        save()
    }

    // MARK: - Auto-archive

    /// Moves tabs nobody has touched for `interval` seconds into the archive.
    func archiveStale(after interval: TimeInterval) {
        guard interval > 0 else { return }
        let cutoff = Date.now.addingTimeInterval(-interval)
        let stale = tabs.filter { $0.lastActive < cutoff }
        guard !stale.isEmpty else { return }

        for tab in stale {
            if let url = tab.url {
                archived.insert(ArchivedTab(id: tab.id, title: tab.displayTitle, url: url, archivedAt: .now), at: 0)
            }
            tab.tearDown()
        }
        let staleIDs = Set(stale.map(\.id))
        tabs.removeAll { staleIDs.contains($0.id) }
        if let activeID, staleIDs.contains(activeID) {
            self.activeID = nil
            showingHome = true
        }
        pruneArchive()
        save()
    }

    func reopen(_ item: ArchivedTab) {
        archived.removeAll { $0.id == item.id }
        open(item.url)
    }

    func removeFromArchive(_ item: ArchivedTab) {
        archived.removeAll { $0.id == item.id }
        save()
    }

    func clearArchive() {
        archived.removeAll()
        save()
    }

    private func pruneArchive() {
        let keepAfter = Date.now.addingTimeInterval(-30 * 24 * 3600)
        archived = Array(archived.filter { $0.archivedAt > keepAfter }.prefix(500))
    }

    // MARK: - Persistence

    private struct TabRecord: Codable {
        let id: UUID
        var title: String
        var url: URL?
        var lastActive: Date
    }

    private struct Snapshot: Codable {
        var tabs: [TabRecord]
        var archived: [ArchivedTab]
    }

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("tabs.json")
    }

    func save() {
        let snapshot = Snapshot(
            tabs: tabs.map { TabRecord(id: $0.id, title: $0.title, url: $0.url, lastActive: $0.lastActive) },
            archived: archived
        )
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
        } catch {
            print("TabStore save failed: \(error)")
        }
    }

    private func restore() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        tabs = snapshot.tabs.map {
            BrowserTab(id: $0.id, title: $0.title, url: $0.url, lastActive: $0.lastActive)
        }
        archived = snapshot.archived
        // Like Arc Search, always launch onto the search screen.
        activeID = nil
        showingHome = true
    }
}
