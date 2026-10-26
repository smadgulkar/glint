import SwiftUI

/// Home: open tabs as cards, plus the big search button.
struct HomeView: View {
    @EnvironmentObject private var store: TabStore
    let onSearch: () -> Void
    let onSettings: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.tabs.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.tabs) { tab in
                            TabCard(tab: tab,
                                    onOpen: { store.select(tab) },
                                    onClose: { store.close(tab) })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Glint")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ArchiveView()
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    .accessibilityLabel("Archive")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Settings", systemImage: "gearshape", action: onSettings)
                        if !store.tabs.isEmpty {
                            Button("Close all tabs", systemImage: "xmark.square", role: .destructive) {
                                store.closeAll()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onSearch) {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                        Text("Search or ask anything")
                        Spacer()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
            Text("Ask a question and Glint reads the web for you.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Answers are written on your iPhone. Nothing you search is sent to an AI server.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .padding(.top, 60)
    }
}

private struct TabCard: View {
    @ObservedObject var tab: BrowserTab
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tab.displayHost)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close tab")
                }
                Text(tab.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
