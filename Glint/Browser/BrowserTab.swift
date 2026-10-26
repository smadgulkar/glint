import Foundation
import Combine
import UIKit
import WebKit

/// One open tab. The WKWebView is created lazily, so imported or restored
/// tabs cost nothing until the person opens them.
@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id: UUID
    @Published var title: String
    @Published var url: URL?
    @Published var lastActive: Date
    @Published var progress: Double = 0
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false

    private var _webView: WKWebView?
    private var observations: [NSKeyValueObservation] = []

    init(id: UUID = UUID(), title: String = "", url: URL? = nil, lastActive: Date = .now) {
        self.id = id
        self.title = title
        self.url = url
        self.lastActive = lastActive
        super.init()
    }

    var displayHost: String {
        url?.host()?.replacingOccurrences(of: "www.", with: "") ?? "New tab"
    }

    var displayTitle: String {
        title.isEmpty ? displayHost : title
    }

    /// The web view for this tab, created (and pointed at `url`) on first use.
    var webView: WKWebView {
        if let existing = _webView { return existing }
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()
        ContentBlocker.shared.install(into: config.userContentController)

        let view = WKWebView(frame: .zero, configuration: config)
        view.allowsBackForwardNavigationGestures = true
        view.navigationDelegate = self
        view.uiDelegate = self
        _webView = view
        observe(view)
        if let url { view.load(URLRequest(url: url)) }
        return view
    }

    func load(_ newURL: URL) {
        url = newURL
        if let existing = _webView {
            existing.load(URLRequest(url: newURL))
        } else {
            _ = webView // creates the view and loads `url`
        }
    }

    func goBack() { _webView?.goBack() }
    func goForward() { _webView?.goForward() }
    func reload() { _webView?.reload() }

    func tearDown() {
        _webView?.stopLoading()
        _webView?.navigationDelegate = nil
        _webView?.uiDelegate = nil
        observations.removeAll()
        _webView = nil
    }

    /// Readable text of the current page, for Summarize.
    func extractText() async throws -> PageText {
        let raw = try await webView.evaluateJavaScript(Scripts.readable)
        return try PageText.decode(raw)
    }

    // MARK: - KVO

    private func observe(_ view: WKWebView) {
        let sync: () -> Void = { [weak self] in
            Task { @MainActor in self?.syncFromWebView() }
        }
        observations = [
            view.observe(\.title, options: [.new]) { _, _ in sync() },
            view.observe(\.url, options: [.new]) { _, _ in sync() },
            view.observe(\.estimatedProgress, options: [.new]) { _, _ in sync() },
            view.observe(\.isLoading, options: [.new]) { _, _ in sync() },
            view.observe(\.canGoBack, options: [.new]) { _, _ in sync() },
            view.observe(\.canGoForward, options: [.new]) { _, _ in sync() },
        ]
    }

    private func syncFromWebView() {
        guard let view = _webView else { return }
        if let pageTitle = view.title, !pageTitle.isEmpty { title = pageTitle }
        if let pageURL = view.url { url = pageURL }
        progress = view.estimatedProgress
        isLoading = view.isLoading
        canGoBack = view.canGoBack
        canGoForward = view.canGoForward
    }

    // MARK: - WKUIDelegate

    /// Links with target="_blank" open in the same tab instead of doing nothing.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let target = navigationAction.request.url {
            webView.load(URLRequest(url: target))
        }
        return nil
    }

    // MARK: - WKNavigationDelegate

    /// Hand mailto:, tel:, App Store and other non-web links to iOS.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let target = navigationAction.request.url,
              let scheme = target.scheme?.lowercased() else { return .allow }
        if ["http", "https", "about", "data", "blob", "file"].contains(scheme) {
            return .allow
        }
        _ = await UIApplication.shared.open(target)
        return .cancel
    }
}
