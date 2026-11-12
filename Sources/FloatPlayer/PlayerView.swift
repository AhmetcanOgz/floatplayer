import AppKit
import FloatPlayerCore
import WebKit

final class PlayerView: NSView {
    let webView: WKWebView
    let topBar = TopBarView()
    private let placeholder = PlaceholderView()
    private var handles: [ResizeHandle] = []
    private var hoverArea: NSTrackingArea?
    private var hideWork: DispatchWorkItem?

    var zoom: CGFloat = 1 { didSet { needsLayout = true } }
    var cropH: CGFloat = 0 { didSet { needsLayout = true } }
    var cropV: CGFloat = 0 { didSet { needsLayout = true } }

    var hasContent = false {
        didSet {
            webView.isHidden = !hasContent
            placeholder.isHidden = hasContent
        }
    }

    init(webView: WKWebView, ratio: @escaping () -> CGFloat?) {
        self.webView = webView
        super.init(frame: NSRect(x: 0, y: 0, width: 480, height: 270))
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 10
        layer?.masksToBounds = true

        webView.isHidden = true
        addSubview(webView)
        addSubview(placeholder)
        addSubview(topBar)
        for edge in ResizeEdge.allEdges {
            let handle = ResizeHandle(edge: edge, ratio: ratio)
            handles.append(handle)
            addSubview(handle)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        webView.frame = FrameMath.contentFrame(size: bounds.size, zoom: zoom, cropH: cropH, cropV: cropV)
        placeholder.frame = bounds
        topBar.frame = NSRect(x: 0, y: bounds.height - TopBarView.height, width: bounds.width, height: TopBarView.height)

        let t: CGFloat = 5
        let c: CGFloat = 14
        let b = bounds
        for handle in handles {
            let e = handle.edge
            let isCorner = (e.contains(.left) || e.contains(.right)) && (e.contains(.top) || e.contains(.bottom))
            var r: NSRect
            if isCorner {
                r = NSRect(x: e.contains(.left) ? 0 : b.width - c, y: e.contains(.bottom) ? 0 : b.height - c, width: c, height: c)
            } else if e == .left || e == .right {
                r = NSRect(x: e == .left ? 0 : b.width - t, y: c, width: t, height: b.height - 2 * c)
            } else {
                r = NSRect(x: c, y: e == .bottom ? 0 : b.height - t, width: b.width - 2 * c, height: t)
            }
            handle.frame = r
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let strip = NSRect(x: 0, y: bounds.height - 56, width: bounds.width, height: 56)
        let area = NSTrackingArea(rect: strip, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hideWork?.cancel()
        topBar.setShown(true)
    }

    override func mouseExited(with event: NSEvent) {
        let work = DispatchWorkItem { [weak self] in self?.topBar.setShown(false) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}

final class TopBarView: NSVisualEffectView {
    static let height: CGFloat = 28

    let titleLabel = NSTextField(labelWithString: "")
    var onOpen: (() -> Void)?
    var onHide: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        alphaValue = 0
        isHidden = true

        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle

        let open = Self.button("link", "URL Aç (⌘L)", #selector(openTapped), self)
        let hide = Self.button("xmark", "Gizle (⌘W)", #selector(hideTapped), self)
        let stack = NSStackView(views: [titleLabel, open, hide])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func button(_ symbol: String, _ tip: String, _ action: Selector, _ target: AnyObject) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage()
        let b = NSButton(image: image, target: target, action: action)
        b.isBordered = false
        b.toolTip = tip
        b.contentTintColor = .secondaryLabelColor
        return b
    }

    @objc private func openTapped() { onOpen?() }
    @objc private func hideTapped() { onHide?() }

    func setShown(_ shown: Bool) {
        if shown { isHidden = false }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            animator().alphaValue = shown ? 1 : 0
        }, completionHandler: { [weak self] in
            guard let self, !shown, self.alphaValue == 0 else { return }
            self.isHidden = true
        })
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

private final class PlaceholderView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        let label = NSTextField(labelWithString: "Bir video bağlantısı yapıştırmak için ⌘L\nya da menü çubuğundaki simgeyi kullanın")
        label.alignment = .center
        label.maximumNumberOfLines = 0
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -24),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var mouseDownCanMoveWindow: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

final class ResizeHandle: NSView {
    static let minSize = CGSize(width: 160, height: 90)

    let edge: ResizeEdge
    private let ratio: () -> CGFloat?

    init(edge: ResizeEdge, ratio: @escaping () -> CGFloat?) {
        self.edge = edge
        self.ratio = ratio
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
    }

    override func cursorUpdate(with event: NSEvent) { cursor.set() }
    override func mouseEntered(with event: NSEvent) { cursor.set() }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let start = window.frame
        let origin = NSEvent.mouseLocation
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), next.type != .leftMouseUp {
            let p = NSEvent.mouseLocation
            let frame = FrameMath.resized(start, edge: edge, dx: p.x - origin.x, dy: p.y - origin.y, ratio: ratio(), minSize: Self.minSize)
            window.setFrame(frame, display: true)
            cursor.set()
        }
    }

    private var cursor: NSCursor {
        if #available(macOS 15.0, *) {
            return NSCursor.frameResize(position: position, directions: .all)
        }
        if edge == .left || edge == .right { return .resizeLeftRight }
        if edge == .top || edge == .bottom { return .resizeUpDown }
        return .crosshair
    }

    @available(macOS 15.0, *)
    private var position: NSCursor.FrameResizePosition {
        switch edge {
        case .left: return .left
        case .right: return .right
        case .top: return .top
        case .bottom: return .bottom
        case [.top, .left]: return .topLeft
        case [.top, .right]: return .topRight
        case [.bottom, .left]: return .bottomLeft
        default: return .bottomRight
        }
    }
}
