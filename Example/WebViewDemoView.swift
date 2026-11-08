import SwiftUI
import WebKit
import PhantomSwift

// MARK: - WebView Demo View

struct WebViewDemoView: View {
    @State private var lastAction = "Page loaded"

    var body: some View {
        List {
            Section(header: Label("WebView Inspector Demo", systemImage: "globe")) {
                Text("Demonstrates hybrid HTML/JS integration with WKWebView. Console logs, DOM structure, scripts, and JS-to-native messages are automatically captured by PhantomSwift.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Label("Embedded WKWebView", systemImage: "doc.richtext")) {
                DemoWebViewRepresentable()
                    .frame(height: 280)
                    .cornerRadius(10)
            }

            Section(header: Label("Inspection Guide", systemImage: "info.circle")) {
                VStack(alignment: .leading, spacing: 8) {
                    guideRow(number: "1", text: "Tap buttons inside the webview above to emit JS logs and postMessage events.")
                    guideRow(number: "2", text: "Open PhantomSwift HUD (shake device or use dynamic island).")
                    guideRow(number: "3", text: "Select 'WebView' to view logs, extract DOM HTML, and run REPL expressions.")
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("WebView Inspector")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }

    private func guideRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - WKWebView Representable

private struct DemoWebViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Register host message handlers
        configuration.userContentController.add(context.coordinator, name: "checkoutBridge")
        configuration.userContentController.add(context.coordinator, name: "analyticsBridge")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Phantom Checkout Demo</title>
          <style>
            body { font-family: -apple-system, sans-serif; padding: 16px; background: #1c1c1e; color: #fff; }
            h2 { font-size: 17px; margin-top: 0; color: #5856d6; }
            p { font-size: 13px; color: #aeaeb2; }
            button {
              display: block; width: 100%; padding: 10px; margin: 8px 0;
              background: #2c2c2e; border: 1px solid #3a3a3c; border-radius: 8px;
              color: #fff; font-size: 13px; font-weight: 600; text-align: left;
            }
            button:active { background: #3a3a3c; }
            .btn-accent { border-color: #5856d6; color: #bf5af2; }
            .btn-warn { border-color: #ff9f0a; color: #ff9f0a; }
            .btn-error { border-color: #ff453a; color: #ff453a; }
          </style>
          <script>
            // Inline demo script
            function logSample() {
              console.log('User tapped Log Info', { timestamp: Date.now(), platform: 'iOS' });
            }
            function warnSample() {
              console.warn('Simulated hybrid bridge latency > 500ms');
            }
            function errorSample() {
              console.error('Simulated TypeError: cannot read property of null');
            }
            function sendCheckout() {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.checkoutBridge) {
                window.webkit.messageHandlers.checkoutBridge.postMessage({
                  orderId: 'ORD-9842',
                  amount: 149.50,
                  currency: 'USD',
                  itemCount: 3
                });
              }
            }
            function sendAnalytics() {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.analyticsBridge) {
                window.webkit.messageHandlers.analyticsBridge.postMessage({
                  event: 'checkout_step_viewed',
                  step: 2
                });
              }
            }
          </script>
        </head>
        <body>
          <h2>Hybrid Web Application</h2>
          <p>Tap below to trigger JavaScript events:</p>
          <button onclick="logSample()">Emit console.log()</button>
          <button class="btn-warn" onclick="warnSample()">Emit console.warn()</button>
          <button class="btn-error" onclick="errorSample()">Emit console.error()</button>
          <button class="btn-accent" onclick="sendCheckout()">postMessage -> checkoutBridge</button>
          <button class="btn-accent" onclick="sendAnalytics()">postMessage -> analyticsBridge</button>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: URL(string: "https://example.com/checkout"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // Host app receives the message as normal
        }
    }
}
