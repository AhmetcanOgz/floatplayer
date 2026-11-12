import AppKit
import FloatPlayerCore
import WebKit

/// `FloatPlayer --check <url> [--no-referer]`: loads the URL like the player does and reports
/// whether a <video> starts without a YouTube player error. Exit code 0 = playing.
final class EmbedChecker: NSObject, NSApplicationDelegate {
    private let input: String
    private let sendReferer: Bool
    private let referer: String?
    private var window: NSWindow?
    private var webView: WKWebView?
    private var attempts = 0

    init(input: String, sendReferer: Bool, referer: String?) {
        self.input = input
        self.sendReferer = sendReferer
        self.referer = referer
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let media = URLResolver.resolve(input) else {
            print("unrecognized input: \(input)")
            exit(2)
        }
        print("resolved: \(media.url.absoluteString) referer: \(sendReferer ? referer ?? media.referer ?? "-" : "-")")

        let webView = WebViewFactory.make()
        let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 640, height: 360), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = webView
        window.orderFrontRegardless()
        webView.load(WebViewFactory.request(for: media, referer: referer, sendReferer: sendReferer))
        self.window = window
        self.webView = webView
        poll()
    }

    private func poll() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.inspect() }
    }

    private func inspect() {
        attempts += 1
        let js = """
        (() => {
          const err = document.querySelector('.ytp-error');
          const v = document.querySelector('video');
          return JSON.stringify({
            href: location.href,
            referrer: document.referrer,
            title: document.title,
            error: err && err.offsetParent !== null ? err.innerText.replace(/\\s+/g, ' ').trim() : '',
            hasVideo: !!v,
            readyState: v ? v.readyState : -1,
            currentTime: v ? v.currentTime : -1,
            paused: v ? v.paused : null
          });
        })()
        """
        webView?.evaluateJavaScript(js) { [weak self] result, error in
            guard let self else { return }
            let json = (result as? String) ?? "error: \(error?.localizedDescription ?? "nil")"
            let info = (result as? String).flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] } ?? [:]
            let failed = !((info["error"] as? String) ?? "").isEmpty
            let playing = ((info["currentTime"] as? Double) ?? 0) > 0.5
            if failed || playing || self.attempts >= 25 {
                print(json)
                print(playing ? "RESULT: playing" : failed ? "RESULT: player error" : "RESULT: timed out")
                exit(playing ? 0 : 1)
            }
            self.poll()
        }
    }
}
