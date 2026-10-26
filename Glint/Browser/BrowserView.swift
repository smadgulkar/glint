import SwiftUI

struct BrowseRequest: Identifiable {
    let id = UUID()
    let query: String
}

struct SummaryRequest: Identifiable {
    let id = UUID()
    let tab: BrowserTab
}

enum SubmitKind {
    case returnKey, searchForMe, webSearch
}

/// Root screen: home (tabs + search) or a tab, with the search sheet on top.
struct BrowserView: View {
    @EnvironmentObject private var store: TabStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var purchases: Purchases
    @EnvironmentObject private var usage: UsageMeter

    @State private var isEditing = true          // Arc Search-style: keyboard up on launch
    @State private var editSeed = ""
    @State private var editFromTab = false
    @State private var browseRequest: BrowseRequest?
    @State private var summaryRequest: SummaryRequest?
    @State private var showSettings = false
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            if !store.showingHome, let tab = store.active {
                TabPageView(
                    tab: tab,
                    onAddressTap: { startEditing(seed: tab.url?.absoluteString ?? "", fromTab: true) },
                    onSummarize: { summarize(tab) },
                    onShowTabs: { store.goHome() }
                )
                .id(tab.id)
            } else {
                HomeView(
                    onSearch: { startEditing(seed: "", fromTab: false) },
                    onSettings: { showSettings = true }
                )
            }

            if isEditing {
                SearchOverlay(
                    seed: editSeed,
                    onSubmit: { text, kind in submit(text, kind: kind) },
                    onCancel: { isEditing = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isEditing)
        .fullScreenCover(item: $browseRequest) { request in
            BrowseForMeView(
                query: request.query,
                onOpen: { url in
                    browseRequest = nil
                    store.open(url)
                },
                onFollowUp: { followUp in
                    browseRequest = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        startSearchForMe(followUp)
                    }
                }
            )
        }
        .sheet(item: $summaryRequest) { request in
            PageSummaryView(tab: request.tab)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Actions

    private func startEditing(seed: String, fromTab: Bool) {
        editSeed = seed
        editFromTab = fromTab
        isEditing = true
    }

    private func submit(_ raw: String, kind: SubmitKind) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isEditing = false

        if kind != .searchForMe, let url = InputParser.url(from: text) {
            store.open(url, inNewTab: !editFromTab)
            return
        }

        let useAI: Bool
        switch kind {
        case .searchForMe: useAI = true
        case .webSearch: useAI = false
        case .returnKey: useAI = settings.returnAction == .searchForMe
        }

        if useAI {
            startSearchForMe(text)
        } else {
            store.open(settings.engine.url(for: text), inNewTab: !editFromTab)
        }
    }

    private func startSearchForMe(_ query: String) {
        guard consumeAIUse() else { return }
        browseRequest = BrowseRequest(query: query)
    }

    private func summarize(_ tab: BrowserTab) {
        guard consumeAIUse() else { return }
        summaryRequest = SummaryRequest(tab: tab)
    }

    /// Counts one AI use against the free daily allowance. Phones without
    /// Apple Intelligence aren't charged, since they only get sources.
    private func consumeAIUse() -> Bool {
        guard AI.status == .available else { return true }
        guard usage.canUse(isPro: purchases.isPro) else {
            showPaywall = true
            return false
        }
        usage.record(isPro: purchases.isPro)
        return true
    }
}
