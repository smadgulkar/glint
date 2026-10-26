import SwiftUI

/// The bottom search bar: type an address, a search, or a question.
struct SearchOverlay: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var text: String
    @FocusState private var focused: Bool

    let onSubmit: (String, SubmitKind) -> Void
    let onCancel: () -> Void

    init(seed: String, onSubmit: @escaping (String, SubmitKind) -> Void, onCancel: @escaping () -> Void) {
        _text = State(initialValue: seed)
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var looksLikeAddress: Bool { InputParser.url(from: trimmed) != nil }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 10) {
                if !trimmed.isEmpty {
                    actionRow
                }
                HStack(spacing: 10) {
                    Image(systemName: looksLikeAddress ? "globe" : "sparkle.magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search, ask, or enter address", text: $text)
                        .focused($focused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .onSubmit { onSubmit(text, .returnKey) }
                    if !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .accessibilityLabel("Clear")
                    }
                    Button("Cancel") { onCancel() }
                        .font(.subheadline)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onAppear { focused = true }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            if looksLikeAddress {
                chip("Open \(InputParser.url(from: trimmed)?.host() ?? "site")", icon: "arrow.up.right") {
                    onSubmit(text, .webSearch)
                }
            } else {
                chip("Search for Me", icon: "sparkles", prominent: true) {
                    onSubmit(text, .searchForMe)
                }
                chip(settings.engine.name, icon: "magnifyingglass") {
                    onSubmit(text, .webSearch)
                }
            }
            Spacer()
        }
    }

    private func chip(_ title: String, icon: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .background(
                    prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}
