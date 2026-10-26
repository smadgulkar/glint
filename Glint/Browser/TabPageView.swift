import SwiftUI

/// A web page with the bottom toolbar.
struct TabPageView: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var store: TabStore
    let onAddressTap: () -> Void
    let onSummarize: () -> Void
    let onShowTabs: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            WebView(tab: tab)
            if tab.isLoading {
                ProgressView(value: tab.progress)
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
            }
            toolbar
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            toolbarButton("chevron.left", label: "Back", enabled: tab.canGoBack) { tab.goBack() }
            toolbarButton("chevron.right", label: "Forward", enabled: tab.canGoForward) { tab.goForward() }

            Button(action: onAddressTap) {
                HStack(spacing: 6) {
                    if tab.url?.scheme == "https" {
                        Image(systemName: "lock.fill").font(.caption2)
                    }
                    Text(tab.displayHost)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: Capsule())
            }
            .buttonStyle(.plain)

            toolbarButton("sparkles", label: "Summarize page", enabled: !tab.isLoading || tab.progress > 0.6, action: onSummarize)
            Button(action: onShowTabs) {
                Text("\(store.tabs.count)")
                    .font(.caption.weight(.bold))
                    .frame(width: 22, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(lineWidth: 1.6))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tabs")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func toolbarButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}
