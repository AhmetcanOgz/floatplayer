import WebKit

/// On ordinary web pages (`.web`), finds the video player (an embedded iframe such as Close/Rapid, or a page's
/// own <video> container) and stretches it over the whole window, hiding the rest of the page.
/// Players that appear late or get swapped (source tabs) are picked up by a MutationObserver.
enum PlayerFocus {
    static func install(on webView: WKWebView, enabled: Bool) {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source: script(enabled: enabled), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    }

    static func uninstall(from webView: WKWebView) {
        webView.configuration.userContentController.removeAllUserScripts()
    }

    /// Applies to the page that is already open; `install` again so later navigations keep the choice.
    static func set(_ enabled: Bool, on webView: WKWebView) {
        install(on: webView, enabled: enabled)
        webView.evaluateJavaScript("window.__floatPlayerFocus && window.__floatPlayerFocus.set(\(enabled))")
    }

    private static func script(enabled: Bool) -> String {
        """
        (() => {
          if (window.__floatPlayerFocus) return;
          // Services with their own full-window player: their pages already fit, and their muted hero trailers would
          // otherwise be mistaken for the player and hide the rest of the page.
          const OWN_PLAYER = /(^|\\.)(netflix|primevideo|amazon|disneyplus|hotstar|max|hbomax|hulu|paramountplus|peacocktv|tv\\.apple|twitch|mubi|crunchyroll|blutv|exxen|gain|tabii|todtv|tod|puhutv|beinconnect|ssport|dsmartgo|tvplus|digiturk)\\.[a-z.]+$/i;
          if (OWN_PLAYER.test(location.hostname)) return;
          const ON = 'fp-focus-on', TARGET = 'fp-focus-target', ANC = 'fp-focus-anc';
          const PLAYER_HINT = /closeload|rapidvid|rapidrame|vidmoly|sibnet|ok\\.ru|dailymotion|vimeo|youtube|filemoon|streamtape|dood|voe|mixdrop|fembed|uqload|vidmoxy|\\/embed|player|video|watch|izle/i;
          let enabled = \(enabled), target = null, targetScore = 0, timer = null;

          const style = document.createElement('style');
          style.textContent = `
            html.${ON}, html.${ON} body { overflow: hidden !important; background: #000 !important; }
            html.${ON} body * { visibility: hidden !important; }
            html.${ON} .${TARGET}, html.${ON} .${TARGET} * { visibility: visible !important; }
            html.${ON} .${TARGET} {
              position: fixed !important; inset: 0 !important; width: 100vw !important; height: 100vh !important;
              max-width: none !important; max-height: none !important; min-width: 0 !important; min-height: 0 !important;
              margin: 0 !important; padding: 0 !important; border: 0 !important; border-radius: 0 !important;
              transform: none !important; z-index: 2147483647 !important; background: #000 !important;
            }
            html.${ON} .${ANC} {
              transform: none !important; filter: none !important; perspective: none !important;
              contain: none !important; will-change: auto !important; backdrop-filter: none !important;
            }`;
          document.documentElement.appendChild(style);

          function visibleRect(el) {
            const r = el.getBoundingClientRect();
            if (r.width < 200 || r.height < 112) return null;
            const cs = getComputedStyle(el);
            if (cs.display === 'none' || Number(cs.opacity) === 0) return null;
            // While focused, everything else is hidden by us, so visibility says nothing then.
            if (cs.visibility === 'hidden' && !document.documentElement.classList.contains(ON)) return null;
            return r;
          }

          function score(el, r) {
            let s = r.width * r.height;
            const ratio = r.width / r.height;
            s *= ratio >= 1.2 && ratio <= 2.5 ? 2 : 0.3;
            // Muted autoplay/loop videos are background trailers and banners, not something being watched.
            if (el.tagName === 'VIDEO') return el.muted && (el.loop || el.autoplay || !el.controls) ? 0 : s * 4;
            const src = el.getAttribute('src') || el.getAttribute('data-src') || '';
            const allow = (el.getAttribute('allow') || '') + (el.hasAttribute('allowfullscreen') ? ' fullscreen' : '');
            const fullscreen = /fullscreen/i.test(allow), hinted = PLAYER_HINT.test(src);
            // Plain iframes are usually ads or widgets; only player-looking ones count.
            if (!fullscreen && !hinted) return 0;
            if (fullscreen) s *= 3;
            if (hinted) s *= 3;
            return s;
          }

          // A <video>'s custom controls live in its wrapper, so take the largest ancestor that is still about video-sized.
          function container(video) {
            const v = video.getBoundingClientRect();
            let el = video;
            for (let p = video.parentElement; p && p !== document.body; p = p.parentElement) {
              const r = p.getBoundingClientRect();
              if (r.width > v.width * 1.1 + 4 || r.height > v.height * 1.25 + 4) break;
              el = p;
            }
            return el;
          }

          function pick() {
            let best = null, bestScore = 0;
            for (const el of document.querySelectorAll('iframe, video')) {
              if (target && (el === target || target.contains(el))) continue;
              const r = visibleRect(el);
              if (!r) continue;
              const s = score(el, r);
              if (s > bestScore) { best = el; bestScore = s; }
            }
            if (!best) return null;
            return { el: best.tagName === 'VIDEO' ? container(best) : best, score: bestScore };
          }

          function clear() {
            document.documentElement.classList.remove(ON);
            document.querySelectorAll('.' + TARGET + ', .' + ANC).forEach(e => e.classList.remove(TARGET, ANC));
            target = null;
            targetScore = 0;
          }

          function apply() {
            if (!enabled) { clear(); return; }
            const found = pick();
            // Keep the current player unless it is gone or a clearly better one appeared (late-loading player).
            if (target && target.isConnected && !(found && found.score > targetScore * 1.5)) return;
            clear();
            if (!found) return;
            const el = found.el;
            target = el;
            targetScore = found.score;
            el.classList.add(TARGET);
            for (let p = el.parentElement; p && p !== document.documentElement; p = p.parentElement) p.classList.add(ANC);
            document.documentElement.classList.add(ON);
          }

          function schedule() {
            clearTimeout(timer);
            timer = setTimeout(apply, 250);
          }

          new MutationObserver(schedule).observe(document.documentElement, {
            childList: true, subtree: true, attributes: true, attributeFilter: ['src', 'style', 'hidden'],
          });
          addEventListener('load', schedule);
          // Some players get their final size only after scripts/CSS settle.
          let tries = 0;
          const retry = setInterval(() => { if (++tries > 20) clearInterval(retry); else apply(); }, 1000);

          window.__floatPlayerFocus = { set(on) { enabled = on; clear(); apply(); } };
          apply();
        })();
        """
    }
}
