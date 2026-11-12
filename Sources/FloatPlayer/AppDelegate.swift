import AppKit
import FloatPlayerCore
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, WKNavigationDelegate, WKUIDelegate {
    private let settings = Settings()
    private var panel: PlayerPanel!
    private var playerView: PlayerView!
    private var statusItem: NSStatusItem!
    private var current: ResolvedMedia?
    private var positionTimer: Timer?

    private static let zoomRange: ClosedRange<CGFloat> = 1.0...3.0
    private static let cropRange: ClosedRange<CGFloat> = 0.0...0.45
    private static let opacityRange: ClosedRange<CGFloat> = 0.3...1.0

    private var lockedRatio: CGFloat? {
        settings.aspectLocked
            ? FrameMath.croppedRatio(base: settings.aspect.value, cropH: settings.cropH, cropV: settings.cropV)
            : nil
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        let webView = WebViewFactory.make()
        webView.navigationDelegate = self
        webView.uiDelegate = self

        playerView = PlayerView(webView: webView) { [weak self] in self?.lockedRatio }
        playerView.zoom = settings.zoom
        playerView.cropH = settings.cropH
        playerView.cropV = settings.cropV
        playerView.topBar.onOpen = { [weak self] in self?.promptForURL(nil) }
        playerView.topBar.onHide = { [weak self] in self?.panel.orderOut(nil) }

        panel = PlayerPanel(contentRect: initialFrame())
        panel.contentView = playerView
        panel.alphaValue = settings.opacity

        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(forName: name, object: panel, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.settings.frame = self.panel.frame
            }
        }

        buildMenus()
        panel.orderFrontRegardless()

        if let input = settings.lastInput, let media = URLResolver.resolve(input, startOverride: settings.lastPosition) {
            load(media, input: input, remember: false)
        }

        positionTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.recordPlaybackPosition()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        settings.frame = panel.frame
    }

    private func initialFrame() -> NSRect {
        if let saved = settings.frame, NSScreen.screens.contains(where: { $0.visibleFrame.intersects(saved) }) {
            return saved
        }
        let size = NSSize(width: 480, height: 480 / (lockedRatio ?? AspectRatio.wide.value))
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return FrameMath.placed(size, at: .bottomRight, in: visible, margin: 16)
    }

    // MARK: - Loading

    private func load(_ media: ResolvedMedia, input: String, remember: Bool) {
        current = media
        if remember {
            settings.lastInput = input
            settings.lastPosition = nil
        }
        playerView.hasContent = true
        playerView.topBar.titleLabel.stringValue = media.url.host ?? input
        playerView.webView.load(WebViewFactory.request(for: media))
    }

    private func open(_ input: String) {
        guard let media = URLResolver.resolve(input) else {
            NSSound.beep()
            return
        }
        load(media, input: input, remember: true)
        panel.orderFrontRegardless()
    }

    private func recordPlaybackPosition() {
        guard case .youtube = current?.kind else { return }
        let js = "(() => { const v = document.querySelector('video'); return v ? v.currentTime : -1 })()"
        playerView.webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let seconds = result as? Double, seconds >= 1 else { return }
            self?.settings.lastPosition = Int(seconds)
        }
    }

    // Links that want a new window open in the player itself.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let host = webView.url?.host { playerView.topBar.titleLabel.stringValue = webView.title?.isEmpty == false ? webView.title! : host }
    }

    // MARK: - Actions

    @objc func promptForURL(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Video bağlantısı"
        alert.informativeText = "YouTube, Kick ya da herhangi bir sayfa adresi yapıştırın."
        alert.addButton(withTitle: "Aç")
        alert.addButton(withTitle: "Vazgeç")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.placeholderString = "https://www.youtube.com/watch?v=…"
        field.stringValue = clipboardURL() ?? settings.lastInput ?? ""
        alert.accessoryView = field
        alert.window.level = .modalPanel
        alert.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        alert.window.initialFirstResponder = field

        if alert.runModal() == .alertFirstButtonReturn {
            open(field.stringValue)
        }
    }

    @objc func openFromClipboard(_ sender: Any?) {
        guard let input = clipboardURL() else {
            NSSound.beep()
            return
        }
        open(input)
    }

    private func clipboardURL() -> String? {
        guard let s = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              URLResolver.resolve(s) != nil else { return nil }
        return s
    }

    @objc func reload(_ sender: Any?) {
        guard let current else { return }
        playerView.webView.load(WebViewFactory.request(for: current))
    }

    @objc func toggleVisible(_ sender: Any?) {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    @objc func setOpacity(_ sender: NSMenuItem) { applyOpacity(CGFloat(sender.tag) / 100) }
    @objc func increaseOpacity(_ sender: Any?) { applyOpacity(settings.opacity + 0.1) }
    @objc func decreaseOpacity(_ sender: Any?) { applyOpacity(settings.opacity - 0.1) }

    private func applyOpacity(_ value: CGFloat) {
        let v = (value * 10).rounded() / 10
        settings.opacity = min(max(v, Self.opacityRange.lowerBound), Self.opacityRange.upperBound)
        panel.alphaValue = settings.opacity
    }

    @objc func zoomIn(_ sender: Any?) { applyZoom(settings.zoom + 0.1) }
    @objc func zoomOut(_ sender: Any?) { applyZoom(settings.zoom - 0.1) }

    private func applyZoom(_ value: CGFloat) {
        let v = (value * 10).rounded() / 10
        settings.zoom = min(max(v, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        playerView.zoom = settings.zoom
    }

    @objc func cropVerticalMore(_ sender: Any?) { applyCrop(h: settings.cropH, v: settings.cropV + 0.025) }
    @objc func cropVerticalLess(_ sender: Any?) { applyCrop(h: settings.cropH, v: settings.cropV - 0.025) }
    @objc func cropHorizontalMore(_ sender: Any?) { applyCrop(h: settings.cropH + 0.025, v: settings.cropV) }
    @objc func cropHorizontalLess(_ sender: Any?) { applyCrop(h: settings.cropH - 0.025, v: settings.cropV) }

    @objc func resetView(_ sender: Any?) {
        applyZoom(1)
        applyCrop(h: 0, v: 0)
    }

    private func applyCrop(h: CGFloat, v: CGFloat) {
        func clamp(_ x: CGFloat) -> CGFloat {
            min(max((x * 1000).rounded() / 1000, Self.cropRange.lowerBound), Self.cropRange.upperBound)
        }
        let old = (h: settings.cropH, v: settings.cropV)
        let new = (h: clamp(h), v: clamp(v))
        guard old != new else { return }
        settings.cropH = new.h
        settings.cropV = new.v
        playerView.cropH = new.h
        playerView.cropV = new.v
        panel.setFrame(FrameMath.recropped(panel.frame, from: old, to: new), display: true, animate: true)
    }

    @objc func toggleAspectLock(_ sender: Any?) {
        settings.aspectLocked.toggle()
        applyAspectToFrame()
    }

    @objc func setAspect(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let aspect = AspectRatio(rawValue: raw) else { return }
        settings.aspect = aspect
        settings.aspectLocked = true
        applyAspectToFrame()
    }

    private func applyAspectToFrame() {
        guard let ratio = lockedRatio else { return }
        panel.setFrame(FrameMath.fitted(panel.frame, ratio: ratio, minSize: ResizeHandle.minSize), display: true, animate: true)
    }

    @objc func moveToCorner(_ sender: NSMenuItem) {
        guard let corner = Corner(rawValue: sender.tag) else { return }
        let visible = (panel.screen ?? NSScreen.main)?.visibleFrame ?? panel.frame
        panel.setFrame(FrameMath.placed(panel.frame.size, at: corner, in: visible, margin: 16), display: true, animate: true)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(setOpacity(_:)):
            item.state = Int((settings.opacity * 100).rounded()) == item.tag ? .on : .off
        case #selector(toggleAspectLock(_:)):
            item.state = settings.aspectLocked ? .on : .off
        case #selector(setAspect(_:)):
            item.state = settings.aspectLocked && (item.representedObject as? String) == settings.aspect.rawValue ? .on : .off
        case #selector(toggleVisible(_:)):
            item.title = panel.isVisible ? "Pencereyi Gizle" : "Pencereyi Göster"
        case #selector(reload(_:)):
            return current != nil
        case #selector(zoomIn(_:)):
            return settings.zoom < Self.zoomRange.upperBound
        case #selector(zoomOut(_:)):
            return settings.zoom > Self.zoomRange.lowerBound
        default:
            break
        }
        return true
    }

    // MARK: - Menus

    private func buildMenus() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "play.rectangle.on.rectangle", accessibilityDescription: "FloatPlayer")
        let statusMenu = NSMenu()
        populate(statusMenu)
        statusItem.menu = statusMenu

        // Never shown (LSUIElement) but needed for key equivalents and copy/paste in text fields.
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "FloatPlayer")
        populate(appMenu)
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Düzen")
        edit.addItem(withTitle: "Geri Al", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Yinele", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Kes", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopyala", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Yapıştır", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Tümünü Seç", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func populate(_ menu: NSMenu) {
        menu.addItem(item("URL Aç…", #selector(promptForURL(_:)), "l"))
        menu.addItem(item("Panodaki Bağlantıyı Aç", #selector(openFromClipboard(_:)), "v", [.command, .shift]))
        menu.addItem(item("Yenile", #selector(reload(_:)), "r"))
        menu.addItem(.separator())
        menu.addItem(item("Pencereyi Gizle", #selector(toggleVisible(_:)), "w"))

        let opacity = NSMenu()
        for percent in stride(from: 100, through: 30, by: -10) {
            let i = item("%\(percent)", #selector(setOpacity(_:)), "")
            i.tag = percent
            opacity.addItem(i)
        }
        opacity.addItem(.separator())
        opacity.addItem(item("Artır", #selector(increaseOpacity(_:)), "]"))
        opacity.addItem(item("Azalt", #selector(decreaseOpacity(_:)), "["))
        menu.addItem(submenu("Saydamlık", opacity))

        let view = NSMenu()
        view.addItem(item("Yakınlaştır", #selector(zoomIn(_:)), "="))
        view.addItem(item("Uzaklaştır", #selector(zoomOut(_:)), "-"))
        view.addItem(.separator())
        view.addItem(item("Üst/Alt Bantları Kırp", #selector(cropVerticalMore(_:)), arrow(NSDownArrowFunctionKey), [.command, .option]))
        view.addItem(item("Üst/Alt Kırpmayı Azalt", #selector(cropVerticalLess(_:)), arrow(NSUpArrowFunctionKey), [.command, .option]))
        view.addItem(item("Yan Bantları Kırp", #selector(cropHorizontalMore(_:)), arrow(NSRightArrowFunctionKey), [.command, .option]))
        view.addItem(item("Yan Kırpmayı Azalt", #selector(cropHorizontalLess(_:)), arrow(NSLeftArrowFunctionKey), [.command, .option]))
        view.addItem(.separator())
        view.addItem(item("Sıfırla", #selector(resetView(_:)), "0"))
        menu.addItem(submenu("Yakınlaştırma ve Kırpma", view))

        let aspect = NSMenu()
        aspect.addItem(item("Oranı Kilitle", #selector(toggleAspectLock(_:)), "k"))
        aspect.addItem(.separator())
        for ratio in AspectRatio.allCases {
            let i = item(ratio.rawValue, #selector(setAspect(_:)), "")
            i.representedObject = ratio.rawValue
            aspect.addItem(i)
        }
        menu.addItem(submenu("En-Boy Oranı", aspect))

        let corners = NSMenu()
        let names: [(Corner, String)] = [(.topLeft, "Sol Üst"), (.topRight, "Sağ Üst"), (.bottomLeft, "Sol Alt"), (.bottomRight, "Sağ Alt")]
        for (index, (corner, title)) in names.enumerated() {
            let i = item(title, #selector(moveToCorner(_:)), String(index + 1))
            i.tag = corner.rawValue
            corners.addItem(i)
        }
        menu.addItem(submenu("Köşeye Yerleştir", corners))

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Çıkış", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func item(_ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.keyEquivalentModifierMask = modifiers
        i.target = self
        return i
    }

    private func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.submenu = menu
        return i
    }

    private func arrow(_ key: Int) -> String {
        String(Character(UnicodeScalar(UInt16(key))!))
    }
}
