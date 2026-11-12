import CoreGraphics

public struct ResizeEdge: OptionSet, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let left = ResizeEdge(rawValue: 1 << 0)
    public static let right = ResizeEdge(rawValue: 1 << 1)
    public static let top = ResizeEdge(rawValue: 1 << 2)
    public static let bottom = ResizeEdge(rawValue: 1 << 3)

    public static let allEdges: [ResizeEdge] = [
        .left, .right, .top, .bottom,
        [.top, .left], [.top, .right], [.bottom, .left], [.bottom, .right],
    ]
}

public enum Corner: Int, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

public enum AspectRatio: String, CaseIterable {
    case wide = "16:9"
    case classic = "4:3"
    case cinema = "21:9"
    case square = "1:1"
    case vertical = "9:16"

    public var value: CGFloat {
        switch self {
        case .wide: return 16.0 / 9.0
        case .classic: return 4.0 / 3.0
        case .cinema: return 21.0 / 9.0
        case .square: return 1
        case .vertical: return 9.0 / 16.0
        }
    }
}

/// Window geometry in AppKit screen coordinates (origin bottom-left).
public enum FrameMath {
    /// Window aspect after cropping: the web content keeps `base`, the window shows its central part.
    public static func croppedRatio(base: CGFloat, cropH: CGFloat, cropV: CGFloat) -> CGFloat {
        base * (1 - cropH) / (1 - cropV)
    }

    /// Frame of the web view inside a container of `size`; anything outside is clipped.
    public static func contentFrame(size: CGSize, zoom: CGFloat, cropH: CGFloat, cropV: CGFloat) -> CGRect {
        let w = size.width * zoom / (1 - cropH)
        let h = size.height * zoom / (1 - cropV)
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    public static func resized(_ start: CGRect, edge: ResizeEdge, dx: CGFloat, dy: CGFloat,
                               ratio: CGFloat?, minSize: CGSize) -> CGRect {
        var w = start.width
        var h = start.height
        if edge.contains(.left) { w -= dx } else if edge.contains(.right) { w += dx }
        if edge.contains(.bottom) { h -= dy } else if edge.contains(.top) { h += dy }

        let horizontal = edge.contains(.left) || edge.contains(.right)
        let vertical = edge.contains(.top) || edge.contains(.bottom)
        if let r = ratio, r > 0 {
            if horizontal && vertical {
                if abs(w / start.width - 1) >= abs(h / start.height - 1) { h = w / r } else { w = h * r }
            } else if horizontal {
                h = w / r
            } else {
                w = h * r
            }
            if w < minSize.width { w = minSize.width; h = w / r }
            if h < minSize.height { h = minSize.height; w = h * r }
        } else {
            w = max(w, minSize.width)
            h = max(h, minSize.height)
        }

        let x: CGFloat
        if edge.contains(.left) { x = start.maxX - w } else if edge.contains(.right) { x = start.minX } else { x = start.midX - w / 2 }
        let y = edge.contains(.top) ? start.minY : start.maxY - h
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Applies `ratio` keeping the width and the top edge fixed.
    public static func fitted(_ frame: CGRect, ratio: CGFloat, minSize: CGSize) -> CGRect {
        var w = frame.width
        var h = w / ratio
        if h < minSize.height { h = minSize.height; w = h * ratio }
        if w < minSize.width { w = minSize.width; h = w / ratio }
        return CGRect(x: frame.midX - w / 2, y: frame.maxY - h, width: w, height: h)
    }

    /// Resizes the window so the (uncropped) web content keeps its size when the crop changes.
    public static func recropped(_ frame: CGRect, from old: (h: CGFloat, v: CGFloat), to new: (h: CGFloat, v: CGFloat)) -> CGRect {
        let w = frame.width * (1 - new.h) / (1 - old.h)
        let h = frame.height * (1 - new.v) / (1 - old.v)
        return CGRect(x: frame.midX - w / 2, y: frame.midY - h / 2, width: w, height: h)
    }

    public static func placed(_ size: CGSize, at corner: Corner, in visible: CGRect, margin: CGFloat) -> CGRect {
        let x: CGFloat
        let y: CGFloat
        switch corner {
        case .topLeft: x = visible.minX + margin; y = visible.maxY - margin - size.height
        case .topRight: x = visible.maxX - margin - size.width; y = visible.maxY - margin - size.height
        case .bottomLeft: x = visible.minX + margin; y = visible.minY + margin
        case .bottomRight: x = visible.maxX - margin - size.width; y = visible.minY + margin
        }
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
