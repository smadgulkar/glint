import SwiftUI
import UIKit

/// Paste anything that contains links (Arc Search's tab export, a note, an email)
/// and every link becomes a tab. Tabs load only when opened.
struct ImportTabsView: View {
    @EnvironmentObject private var store: TabStore
    @State private var text = ""
    @State private var importedCount: Int?

    private var found: [URL] { InputParser.urls(in: text) }

    var body: some View {
        Form {
            Section {
                Text("In Arc Search, open the tab switcher, then Settings, then Export Data. Copy the list, then paste it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Paste from clipboard", systemImage: "doc.on.clipboard") {
                    text = UIPasteboard.general.string ?? ""
                }
                TextEditor(text: $text)
                    .frame(minHeight: 160)
                    .font(.footnote.monospaced())
            } footer: {
                Text(found.isEmpty ? "No links found yet." : "\(found.count) links found.")
            }

            Section {
                Button("Import \(found.count) tabs") {
                    let urls = found
                    store.addLazily(urls)
                    importedCount = urls.count
                    text = ""
                }
                .disabled(found.isEmpty)
                if let importedCount {
                    Label("Imported \(importedCount) tabs. They're on your home screen.", systemImage: "checkmark.circle")
                }
            }
        }
        .navigationTitle("Import tabs")
    }
}
