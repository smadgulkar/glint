import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var purchases: Purchases
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)

                Text("You've used today's \(UsageMeter.freeDailyLimit) free AI answers")
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    feature("infinity", "Unlimited Search for Me answers and page summaries")
                    feature("iphone", "Runs on your iPhone. Nothing you ask goes to an AI server")
                    feature("creditcard", "Pay once. No subscription, ever")
                }

                Spacer()

                Button {
                    Task {
                        await purchases.buy()
                        if purchases.isPro { dismiss() }
                    }
                } label: {
                    Text(purchases.isBusy ? "One moment…" : "Unlock Glint Pro · \(purchases.priceText)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(purchases.isBusy)

                HStack {
                    Button("Restore purchase") {
                        Task {
                            await purchases.restore()
                            if purchases.isPro { dismiss() }
                        }
                    }
                    Spacer()
                    Text("Free answers reset tomorrow")
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)

                if let error = purchases.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now") { dismiss() }
                }
            }
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
