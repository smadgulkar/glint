import Foundation
import WebKit

/// Loads a page in an off-screen web view and pulls out its text.
/// Pages load exactly as in Safari (JavaScript included), on the person's own device.
@MainActor
final class PageReader: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var continuation: CheckedContinuation<Void, Error>?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        ContentBlocker.shared.install(into: config.userContentController)
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        super.init()
        webView.navigationDelegate = self
    }

    /// Reads one page. Returns nil instead of throwing so one bad source doesn't sink an answer.
    static func read(_ url: URL, timeout: TimeInterval = 8) async -> PageText? {
        let reader = PageReader()
        do {
            try await reader.load(url, timeout: timeout)
            return try PageText.decode(try await reader.evaluate(Scripts.readable))
        } catch {
            return nil
        }
    }

    /// Resolves when the page finishes, fails, or the timeout passes (whichever is first).
    func load(_ url: URL, timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            webView.load(URLRequest(url: url, timeoutInterval: timeout))
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.finish(nil) // slow page: use whatever has rendered so far
            }
        }
    }

    func evaluate(_ script: String) async throws -> Any? {
        try await webView.evaluateJavaScript(script)
    }

    private func finish(_ error: Error?) {
        guard let continuation else { return }
        self.continuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give script-rendered pages a moment to fill in.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            self?.finish(nil)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        finish(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        finish(error)
    }
}
