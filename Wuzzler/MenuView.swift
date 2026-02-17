import SwiftUI
@preconcurrency import StoreKit

struct MenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        HowToPlayView()
                    } label: {
                        Label("How to Play", systemImage: "questionmark.circle")
                    }

                    NavigationLink {
                        StatisticsView()
                    } label: {
                        Label("Statistics", systemImage: "chart.bar")
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }

                Section {
                    Button {
                        requestReview()
                    } label: {
                        Label("Rate & Review", systemImage: "star")
                            .foregroundColor(.primary)
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share with Friends", systemImage: "square.and.arrow.up")
                            .foregroundColor(.primary)
                    }

                    Button {
                        openFeedbackEmail()
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareActivityView(items: ["Check out Wuzzler — daily word puzzles!"])
            }
        }
    }

    @MainActor
    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }

    private func openFeedbackEmail() {
        let subject = "Wuzzler Feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Wuzzler+Feedback"
        if let url = URL(string: "mailto:feedback@wuzzler.app?subject=\(subject)") {
            UIApplication.shared.open(url)
        }
    }
}

struct ShareActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
