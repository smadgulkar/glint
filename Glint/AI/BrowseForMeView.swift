import SwiftUI

/// The answer page: headline, cited points, sources and follow-up questions.
struct BrowseForMeView: View {
    @StateObject private var model: BrowseForMeModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    let onOpen: (URL) -> Void
    let onFollowUp: (String) -> Void

    init(query: String, onOpen: @escaping (URL) -> Void, onFollowUp: @escaping (String) -> Void) {
        _model = StateObject(wrappedValue: BrowseForMeModel(query: query))
        self.onOpen = onOpen
        self.onFollowUp = onFollowUp
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(model.query)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    statusView

                    if let answer = model.answer {
                        answerView(answer)
                    }

                    if !model.sources.isEmpty {
                        sourcesView
                    }

                    if let answer = model.answer, !answer.followUps.isEmpty {
                        followUpsView(answer.followUps)
                    }

                    Button {
                        onOpen(settings.engine.url(for: model.query))
                    } label: {
                        Label("See all results on \(settings.engine.name)", systemImage: "magnifyingglass")
                            .font(.subheadline)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await model.run() }
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.phase {
        case .searching:
            progressRow("Searching the web…")
        case .reading(let hosts):
            progressRow("Reading \(hosts)…")
        case .writing:
            progressRow("Writing your answer on this iPhone…")
        case .done:
            EmptyView()
        case .noAI(let message), .failed(let message):
            Label(message, systemImage: "info.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func progressRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func answerView(_ answer: BrowseAnswer) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(answer.headline)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(answer.points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let cited = source(numbered: point.source) {
                            Button {
                                if let url = URL(string: cited.url) { onOpen(url) }
                            } label: {
                                Text("\(point.source) · \(cited.host)")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(.secondarySystemBackground), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var sourcesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sources")
                .font(.headline)
            ForEach(Array(model.sources.enumerated()), id: \.element.id) { index, result in
                Button {
                    if let url = URL(string: result.url) { onOpen(url) }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(index + 1) · \(result.host)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(result.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        if model.answer == nil, !result.snippet.isEmpty {
                            Text(result.snippet)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func followUpsView(_ questions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ask next")
                .font(.headline)
            ForEach(questions, id: \.self) { question in
                Button {
                    onFollowUp(question)
                } label: {
                    Label(question, systemImage: "sparkles")
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func source(numbered number: Int) -> SearchResult? {
        let index = number - 1
        return model.sources.indices.contains(index) ? model.sources[index] : nil
    }
}
