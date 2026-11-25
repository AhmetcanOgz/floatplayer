import AppKit
import FloatPlayerCore
import WebKit

/// `FloatPlayer --check <url> [--no-referer]`: loads the URL like the player does and reports
/// whether a <video> starts without a YouTube player error. Exit code 0 = playing.
/// With `--layout`: reports whether the page's player (largest iframe/video) fills the window. Exit 0 = fills.
final class EmbedChecker: NSObject, NSApplicationDelegate {
    private let input: String
    private let sendReferer: Bool
    private let referer: String?
    private let layout: Bool
    private var window: NSWindow?
    private var webView: WKWebView?
    private var attempts = 0

    init(input: String, sendReferer: Bool, referer: String?, layout: Bool = false) {
        self.input = input
        self.sendReferer = sendReferer
        self.referer = referer
        self.layout = layout
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let media = URLResolver.resolve(input) else {
            print("unrecognized input: \(input)")
            exit(2)
        }
        print("resolved: \(media.url.absoluteString) referer: \(sendReferer ? referer ?? media.referer ?? "-" : "-")")

        let webView = WebViewFactory.make()
        if case .web = media.kind, !CommandLine.arguments.contains("--no-focus") {
            PlayerFocus.install(on: webView, enabled: true)
        }
        let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 640, height: 360), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = webView
        window.orderFrontRegardless()
        webView.load(WebViewFactory.request(for: media, referer: referer, sendReferer: sendReferer))
        self.window = window
        self.webView = webView
        if layout {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.inspectLayout() }
        } else {
            poll()
        }
    }

    private func inspectLayout() {
        let js = """
        (() => {
          const full = [...document.querySelectorAll('iframe[allowfullscreen], iframe[allow*="fullscreen"], video')];
          const els = (full.length ? full : [...document.querySelectorAll('iframe, video')]).map(e => [e, e.getBoundingClientRect()]);
          els.sort((a, b) => b[1].width * b[1].height - a[1].width * a[1].height);
          const [el, r] = els[0] || [null, null];
          const vis = el ? getComputedStyle(el).visibility : '';
          const hit = document.elementFromPoint(innerWidth / 2, innerHeight / 2);
          return JSON.stringify({
            viewport: [innerWidth, innerHeight],
            player: el ? { tag: el.tagName, src: el.src || '', rect: [r.x, r.y, r.width, r.height].map(Math.round), visibility: vis } : null,
            centerHitIsPlayer: !!el && hit === el,
            bottomHit: (document.elementFromPoint(innerWidth / 2, innerHeight - 5) || {}).className || '',
            otherVisibleText: (document.body.innerText || '').trim().slice(0, 60)
          });
        })()
        """
        webView?.evaluateJavaScript(js) { result, error in
            let json = (result as? String) ?? "error: \(error?.localizedDescription ?? "nil")"
            print(json)
            let info = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
            let vp = info["viewport"] as? [Double] ?? [0, 0]
            let rect = (info["player"] as? [String: Any])?["rect"] as? [Double] ?? [0, 0, 0, 0]
            let fills = vp[0] > 0 && rect[0] <= 1 && rect[1] <= 1 && rect[2] >= vp[0] - 2 && rect[3] >= vp[1] - 2
            let clickable = info["centerHitIsPlayer"] as? Bool ?? false
            print(fills && clickable ? "RESULT: player fills window" : "RESULT: player does not fill window")
            exit(fills && clickable ? 0 : 1)
        }
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
