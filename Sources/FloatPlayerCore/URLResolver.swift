import Foundation

public struct ResolvedMedia: Equatable {
    public enum Kind: Equatable {
        case youtube(id: String)
        case kick(channel: String)
        case web
    }

    public let kind: Kind
    public let url: URL
    public let referer: String?
}

public enum URLResolver {
    // No Referer → "Error 153"; youtube.com itself as Referer → "video unavailable". Any other https origin works.
    public static let youtubeReferer = "https://floatplayer.app/"

    private static let youtubeHosts: Set<String> = [
        "youtube.com", "m.youtube.com", "music.youtube.com", "youtube-nocookie.com",
    ]
    private static let kickReservedPaths: Set<String> = [
        "browse", "categories", "category", "clips", "following", "search", "video", "videos",
        "terms-of-service", "privacy-policy", "dashboard", "settings", "subscriptions",
    ]

    public static func resolve(_ input: String, startOverride: Int? = nil) -> ResolvedMedia? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let comps = URLComponents(string: withScheme),
              let scheme = comps.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let rawHost = comps.host?.lowercased(), rawHost.contains("."),
              let url = comps.url
        else { return nil }

        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        let path = comps.path.split(separator: "/").map(String.init)

        if let id = youtubeID(host: host, path: path, comps: comps) {
            let start = startOverride ?? youtubeStart(comps)
            return ResolvedMedia(kind: .youtube(id: id), url: youtubeEmbedURL(id: id, start: start, list: query(comps, "list")), referer: youtubeReferer)
        }

        if host == "kick.com", path.count == 1, !kickReservedPaths.contains(path[0].lowercased()) {
            let channel = path[0]
            return ResolvedMedia(kind: .kick(channel: channel), url: URL(string: "https://player.kick.com/\(channel)")!, referer: nil)
        }
        if host == "player.kick.com", path.count == 1 {
            return ResolvedMedia(kind: .kick(channel: path[0]), url: url, referer: nil)
        }

        return ResolvedMedia(kind: .web, url: url, referer: nil)
    }

    public static func youtubeEmbedURL(id: String, start: Int?, list: String? = nil) -> URL {
        var c = URLComponents(string: "https://www.youtube.com/embed/\(id)")!
        var items = [
            URLQueryItem(name: "autoplay", value: "1"),
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "rel", value: "0"),
        ]
        if let start, start > 0 { items.append(URLQueryItem(name: "start", value: String(start))) }
        if let list, !list.isEmpty { items.append(URLQueryItem(name: "list", value: list)) }
        c.queryItems = items
        return c.url!
    }

    /// Parses YouTube time values: "90", "90s", "1m30s", "1h2m3s", "1m30".
    public static func parseSeconds(_ raw: String) -> Int? {
        let s = raw.lowercased()
        if let n = Int(s) { return n >= 0 ? n : nil }
        let units: [Character: Int] = ["h": 3600, "m": 60, "s": 1]
        var total = 0
        var digits = ""
        var sawUnit = false
        for ch in s {
            if ch.isASCII, ch.isNumber {
                digits.append(ch)
            } else {
                guard let mult = units[ch], let v = Int(digits) else { return nil }
                total += v * mult
                digits = ""
                sawUnit = true
            }
        }
        if !digits.isEmpty {
            guard let v = Int(digits) else { return nil }
            total += v
        }
        return sawUnit ? total : nil
    }

    private static func youtubeID(host: String, path: [String], comps: URLComponents) -> String? {
        var candidate: String?
        if host == "youtu.be" {
            candidate = path.first
        } else if youtubeHosts.contains(host) {
            if path.first == "watch" {
                candidate = query(comps, "v")
            } else if path.count >= 2, ["shorts", "live", "embed", "v"].contains(path[0]) {
                candidate = path[1]
            }
        }
        guard let id = candidate, isYouTubeID(id) else { return nil }
        return id
    }

    private static func youtubeStart(_ comps: URLComponents) -> Int? {
        if let t = query(comps, "t") ?? query(comps, "start"), let s = parseSeconds(t) { return s }
        if let fragment = comps.fragment, fragment.hasPrefix("t="), let s = parseSeconds(String(fragment.dropFirst(2))) {
            return s
        }
        return nil
    }

    private static func isYouTubeID(_ s: String) -> Bool {
        s.count == 11 && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    private static func query(_ comps: URLComponents, _ name: String) -> String? {
        comps.queryItems?.first { $0.name == name }?.value
    }
}
