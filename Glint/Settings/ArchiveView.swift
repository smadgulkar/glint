import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject private var store: TabStore

    var body: some View {
        List {
            if store.archived.isEmpty {
                Text("Tabs you haven't opened in a while move here automatically, so your home screen stays clean.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.archived) { item in
                Button {
                    store.reopen(item)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text("\(item.url.host() ?? "") · \(item.archivedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("Delete", role: .destructive) { store.removeFromArchive(item) }
                }
            }
        }
        .navigationTitle("Archive")
        .toolbar {
            if !store.archived.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) { store.clearArchive() }
                }
            }
        }
    }
}
