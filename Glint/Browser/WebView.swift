import SwiftUI
import WebKit

/// Shows a tab's existing WKWebView. The view belongs to the tab, so switching
/// tabs keeps each page's scroll position and history.
struct WebView: UIViewRepresentable {
    let tab: BrowserTab

    func makeUIView(context: Context) -> WKWebView {
        tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
