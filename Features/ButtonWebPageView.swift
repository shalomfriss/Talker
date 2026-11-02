import SwiftUI
import WebKit

struct ButtonWebPageView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let url: URL
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var reloadID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                WebPageCanvas(url: url, isLoading: $isLoading, loadFailed: $loadFailed)
                    .id(reloadID)
                if loadFailed {
                    ContentUnavailableView {
                        Label("Could not open page", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Check your internet connection or the address on this button.")
                    } actions: {
                        Button("Try again") {
                            loadFailed = false
                            isLoading = true
                            reloadID = UUID()
                        }
                    }
                    .background(Color(uiColor: .systemBackground))
                } else if isLoading {
                    ProgressView("Loading page")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("web-button-done")
                }
            }
        }
        .accessibilityIdentifier("web-button-page")
    }
}

private struct WebPageCanvas: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadFailed: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadFailed: $loadFailed)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var isLoading: Bool
        @Binding var loadFailed: Bool

        init(isLoading: Binding<Bool>, loadFailed: Binding<Bool>) {
            _isLoading = isLoading
            _loadFailed = loadFailed
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            let address = action.request.url
            let allowed = address?.scheme?.lowercased() == "https" ||
                address?.absoluteString == "about:blank"
            if !allowed && action.targetFrame?.isMainFrame != false {
                isLoading = false
                loadFailed = true
            }
            return allowed ? .allow : .cancel
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if action.targetFrame == nil, action.request.url?.scheme?.lowercased() == "https" {
                webView.load(action.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            loadFailed = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            loadFailed = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            isLoading = false
            loadFailed = true
        }
    }
}
