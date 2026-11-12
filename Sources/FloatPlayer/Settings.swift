import AppKit
import FloatPlayerCore

final class Settings {
    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            "opacity": 1.0,
            "zoom": 1.0,
            "cropH": 0.0,
            "cropV": 0.0,
            "aspectLocked": true,
            "aspect": AspectRatio.wide.rawValue,
        ])
    }

    var frame: NSRect? {
        get { defaults.string(forKey: "frame").map(NSRectFromString).flatMap { $0.isEmpty ? nil : $0 } }
        set { defaults.set(newValue.map(NSStringFromRect), forKey: "frame") }
    }

    var lastInput: String? {
        get { defaults.string(forKey: "lastInput") }
        set { defaults.set(newValue, forKey: "lastInput") }
    }

    /// Last known playback second of a YouTube video, used to resume on next launch.
    var lastPosition: Int? {
        get { let v = defaults.integer(forKey: "lastPosition"); return v > 0 ? v : nil }
        set { defaults.set(newValue ?? 0, forKey: "lastPosition") }
    }

    var opacity: CGFloat {
        get { CGFloat(defaults.double(forKey: "opacity")) }
        set { defaults.set(Double(newValue), forKey: "opacity") }
    }

    var zoom: CGFloat {
        get { CGFloat(defaults.double(forKey: "zoom")) }
        set { defaults.set(Double(newValue), forKey: "zoom") }
    }

    var cropH: CGFloat {
        get { CGFloat(defaults.double(forKey: "cropH")) }
        set { defaults.set(Double(newValue), forKey: "cropH") }
    }

    var cropV: CGFloat {
        get { CGFloat(defaults.double(forKey: "cropV")) }
        set { defaults.set(Double(newValue), forKey: "cropV") }
    }

    var aspectLocked: Bool {
        get { defaults.bool(forKey: "aspectLocked") }
        set { defaults.set(newValue, forKey: "aspectLocked") }
    }

    var aspect: AspectRatio {
        get { defaults.string(forKey: "aspect").flatMap(AspectRatio.init(rawValue:)) ?? .wide }
        set { defaults.set(newValue.rawValue, forKey: "aspect") }
    }
}
