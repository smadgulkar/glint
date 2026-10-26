import Foundation

/// JavaScript run inside web views. Each script returns a JSON string, because
/// WKWebView's async evaluateJavaScript throws when a script returns undefined.
enum Scripts {
    /// The readable text of a page: article/main content without menus, footers and scripts.
    static let readable = #"""
    (() => {
      const root = document.querySelector('article') || document.querySelector('main') ||
                   document.querySelector('[role="main"]') || document.body;
      if (!root) { return JSON.stringify({ title: document.title || '', text: '' }); }
      const clone = root.cloneNode(true);
      clone.querySelectorAll('script,style,noscript,nav,footer,header,aside,form,iframe,svg,button,figure,[aria-hidden="true"]')
        .forEach(n => n.remove());
      const blocks = Array.from(clone.querySelectorAll('h1,h2,h3,h4,p,li,blockquote,pre,td'))
        .map(n => (n.textContent || '').replace(/\s+/g, ' ').trim())
        .filter(t => t.length > 0);
      let text = blocks.join('\n');
      if (text.length < 200) {
        text = (clone.textContent || '').replace(/[ \t]+/g, ' ').replace(/\n\s*\n+/g, '\n').trim();
      }
      return JSON.stringify({ title: document.title || '', text: text.slice(0, 20000) });
    })();
    """#

    /// Organic results from DuckDuckGo's HTML results page (ads skipped).
    static let searchResults = #"""
    (() => {
      const out = [];
      const seen = new Set();
      const push = (href, title, snippet) => {
        try {
          const u = new URL(href, location.href);
          const real = u.searchParams.get('uddg');
          const finalURL = real ? real : u.href;
          if (!/^https?:/i.test(finalURL)) return;
          if (/duckduckgo\.com/i.test(new URL(finalURL).hostname)) return;
          if (seen.has(finalURL)) return;
          seen.add(finalURL);
          out.push({ url: finalURL, title: (title || '').trim(), snippet: (snippet || '').trim() });
        } catch (e) {}
      };
      document.querySelectorAll('.result').forEach(r => {
        if (r.classList.contains('result--ad')) return;
        const a = r.querySelector('a.result__a');
        if (!a) return;
        const s = r.querySelector('.result__snippet');
        push(a.getAttribute('href') || '', a.textContent, s ? s.textContent : '');
      });
      if (out.length === 0) {
        document.querySelectorAll('a[href]').forEach(a => push(a.getAttribute('href'), a.textContent, ''));
      }
      return JSON.stringify(out.slice(0, 10));
    })();
    """#
}

struct PageText: Decodable {
    let title: String
    let text: String

    /// Decodes the JSON string returned by `Scripts.readable`.
    static func decode(_ raw: Any?) throws -> PageText {
        guard let json = raw as? String else { throw ReaderError.noContent }
        return try JSONDecoder().decode(PageText.self, from: Data(json.utf8))
    }
}

enum ReaderError: LocalizedError {
    case noContent
    case noResults

    var errorDescription: String? {
        switch self {
        case .noContent: return "Couldn't read this page."
        case .noResults: return "No results came back for that search."
        }
    }
}
