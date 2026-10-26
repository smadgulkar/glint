import SwiftUI

/// Summarize the page you're on (the sparkles button).
struct PageSummaryView: View {
    let tab: BrowserTab
    @State private var summary: PageSummary?
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(tab.displayTitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if let summary {
                        Text(summary.tldr)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(Array(summary.points.enumerated()), id: \.offset) { _, point in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("•").foregroundStyle(Color.accentColor)
                                Text(point).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else if let message {
                        Label(message, systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Reading this page on your iPhone…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await run() }
    }

    private func run() async {
        if case .unavailable(let reason) = AI.status {
            message = reason
            return
        }
        do {
            let page = try await tab.extractText()
            guard page.text.count > 80 else {
                message = "There isn't enough text on this page to summarize."
                return
            }
            summary = try await AI.summarize(title: page.title, text: page.text)
        } catch {
            message = AI.friendlyMessage(for: error)
        }
    }
}
