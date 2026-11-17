import SwiftUI
import UIKit
import WebKit

@MainActor
@Observable
final class ServerModel {
    var url: URL?
    var error: String?
    private var started = false

    func start() async {
        guard !started else { return }
        started = true
        do {
            let port = try await LocalServer.shared.start()
            url = URL(string: "http://127.0.0.1:\(port)/")
        } catch {
            self.error = (error as? LocalServer.Failure)?.description ?? error.localizedDescription
        }
    }
}

struct RootView: View {
    @State private var model = ServerModel()

    var body: some View {
        ZStack {
            Color.pavement.ignoresSafeArea()
            if let url = model.url {
                WebShell(url: url)
                    .ignoresSafeArea()
            } else if let error = model.error {
                Text(error)
                    .font(.body)
                    .padding()
            } else {
                ProgressView("Starting Heya")
            }
        }
        .task { await model.start() }
    }
}

extension Color {
    /// Sidewalk from DESIGN.md: concrete in light mode, asphalt in dark.
    static let pavement = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x2b / 255, green: 0x2d / 255, blue: 0x30 / 255, alpha: 1)
            : UIColor(red: 0xd5 / 255, green: 0xd2 / 255, blue: 0xca / 255, alpha: 1)
    })
}

struct WebShell: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let script = WKUserScript(source: Self.safeAreaCSS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.isInspectable = true
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    /// The page was written for a browser window. On a phone, keep the chalk
    /// pavement under the status bar and notch without editing `app/index.html`.
    static let safeAreaCSS = """
    (function () {
      var meta = document.querySelector('meta[name="viewport"]');
      if (meta) meta.setAttribute('content', 'width=device-width, initial-scale=1, viewport-fit=cover');
      var style = document.createElement('style');
      style.textContent = 'body{padding-top:env(safe-area-inset-top);padding-right:env(safe-area-inset-right);padding-bottom:env(safe-area-inset-bottom);padding-left:env(safe-area-inset-left);}';
      document.documentElement.appendChild(style);
    })();
    """

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               let host = url.host,
               host != "127.0.0.1", host != "localhost" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
