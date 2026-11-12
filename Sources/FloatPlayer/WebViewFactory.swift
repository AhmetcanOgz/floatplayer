import FloatPlayerCore
import WebKit

enum WebViewFactory {
    static func make() -> WKWebView {
        let config = WKWebViewConfiguration()
        // Default (persistent) store so cookies and YouTube sign-in survive restarts.
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.applicationNameForUserAgent = "Version/26.0 Safari/605.1.15"

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.underPageBackgroundColor = .black
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    static func request(for media: ResolvedMedia, referer override: String? = nil, sendReferer: Bool = true) -> URLRequest {
        var request = URLRequest(url: media.url)
        if sendReferer, let referer = override ?? media.referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        return request
    }
}
