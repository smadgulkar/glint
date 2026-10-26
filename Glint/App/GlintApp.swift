import SwiftUI

@main
struct GlintApp: App {
    @StateObject private var store = TabStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var purchases = Purchases()
    @StateObject private var usage = UsageMeter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(purchases)
                .environmentObject(usage)
                .task {
                    ContentBlocker.shared.enabled = settings.blockAds
                    await ContentBlocker.shared.prepare()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.archiveStale(after: settings.archiveInterval.seconds)
                usage.rollOverIfNeeded()
            case .background:
                store.save()
            default:
                break
            }
        }
    }
}
