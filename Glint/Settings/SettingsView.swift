import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var purchases: Purchases
    @EnvironmentObject private var usage: UsageMeter
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    Picker("Search engine", selection: $settings.engine) {
                        ForEach(SearchEngine.allCases) { Text($0.name).tag($0) }
                    }
                    Picker("Return key", selection: $settings.returnAction) {
                        ForEach(ReturnAction.allCases) { Text($0.name).tag($0) }
                    }
                }

                Section {
                    Picker("Archive unused tabs", selection: $settings.archiveInterval) {
                        ForEach(ArchiveInterval.allCases) { Text($0.name).tag($0) }
                    }
                    Toggle("Block ads and trackers", isOn: $settings.blockAds)
                } header: {
                    Text("Tabs")
                } footer: {
                    Text("Archived tabs stay in the archive for 30 days.")
                }

                Section("Move from Arc Search") {
                    NavigationLink("Import tabs") { ImportTabsView() }
                }

                Section("AI") {
                    switch AI.status {
                    case .available:
                        Label("Apple Intelligence is on. Answers are written on this iPhone.", systemImage: "checkmark.circle")
                    case .unavailable(let reason):
                        Label(reason, systemImage: "exclamationmark.circle")
                    }
                    if !purchases.isPro {
                        Text("Free answers left today: \(usage.remainingToday) of \(UsageMeter.freeDailyLimit)")
                    }
                }

                Section("Glint Pro") {
                    if purchases.isPro {
                        Label("Unlocked. Thank you!", systemImage: "checkmark.seal.fill")
                    } else {
                        Button("Unlock unlimited AI · \(purchases.priceText) once") { showPaywall = true }
                        Button("Restore purchase") { Task { await purchases.restore() } }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}
