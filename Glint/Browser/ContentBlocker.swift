import Foundation
import WebKit

/// Compiles the bundled ad/tracker list once and attaches it to every web view.
@MainActor
final class ContentBlocker {
    static let shared = ContentBlocker()

    var enabled = true
    private(set) var ruleList: WKContentRuleList?
    private let controllers = NSHashTable<WKUserContentController>.weakObjects()

    func prepare() async {
        guard ruleList == nil,
              let fileURL = Bundle.main.url(forResource: "blocklist", withExtension: "json"),
              let json = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        do {
            ruleList = try await WKContentRuleListStore.default()
                .compileContentRuleList(forIdentifier: "glint-blocklist-v1", encodedContentRuleList: json)
            setEnabled(enabled) // attach to web views created before compiling finished
        } catch {
            print("Content blocker failed to compile: \(error)")
        }
    }

    func install(into controller: WKUserContentController) {
        controllers.add(controller)
        if enabled, let ruleList {
            controller.add(ruleList)
        }
    }

    /// Takes effect on each tab's next page load.
    func setEnabled(_ on: Bool) {
        enabled = on
        for controller in controllers.allObjects {
            controller.removeAllContentRuleLists()
            if on, let ruleList {
                controller.add(ruleList)
            }
        }
    }
}
