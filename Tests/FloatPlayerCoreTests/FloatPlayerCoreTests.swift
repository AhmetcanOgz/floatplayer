import CoreGraphics
import FloatPlayerCore
import Testing

private func embed(_ input: String) -> String? {
    URLResolver.resolve(input)?.url.absoluteString
}

private func close(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.01 }

@Suite struct URLResolverTests {
    @Test func youTubeWatchWithTime() {
        let m = URLResolver.resolve("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1m30s")
        #expect(m?.kind == .youtube(id: "dQw4w9WgXcQ"))
        #expect(m?.url.absoluteString == "https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&playsinline=1&rel=0&start=90")
    }

    @Test func youTubeRefererIsThirdPartyHTTPS() {
        let referer = URLResolver.resolve("youtu.be/dQw4w9WgXcQ")?.referer
        #expect(referer?.hasPrefix("https://") == true)
        #expect(referer?.contains("youtube.com") == false)
    }

    @Test func youTubeVariants() {
        let base = "https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&playsinline=1&rel=0"
        #expect(embed("youtu.be/dQw4w9WgXcQ?t=42") == base + "&start=42")
        #expect(embed("https://youtube.com/shorts/dQw4w9WgXcQ") == base)
        #expect(embed("https://www.youtube.com/live/dQw4w9WgXcQ?si=abc") == base)
        #expect(embed("https://m.youtube.com/watch?v=dQw4w9WgXcQ#t=10") == base + "&start=10")
        #expect(embed("https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL123") == base + "&list=PL123")
    }

    @Test func startOverride() {
        let m = URLResolver.resolve("youtu.be/dQw4w9WgXcQ?t=5", startOverride: 300)
        #expect(m?.url.query == "autoplay=1&playsinline=1&rel=0&start=300")
    }

    @Test func kick() {
        let m = URLResolver.resolve("https://kick.com/xqc")
        #expect(m?.kind == .kick(channel: "xqc"))
        #expect(m?.url.absoluteString == "https://player.kick.com/xqc")
        #expect(URLResolver.resolve("kick.com/categories")?.kind == .web)
    }

    @Test func unknownOpensAsIs() {
        #expect(URLResolver.resolve("https://vimeo.com/123")?.kind == .web)
        #expect(embed("example.com/a?b=c") == "https://example.com/a?b=c")
        #expect(URLResolver.resolve("https://www.youtube.com/")?.kind == .web)
        #expect(URLResolver.resolve("not a url") == nil)
        #expect(URLResolver.resolve("ftp://x.com") == nil)
    }

    @Test(arguments: [("90", 90), ("90s", 90), ("1h2m3s", 3723), ("1m30", 90)])
    func parseSeconds(input: String, expected: Int) {
        #expect(URLResolver.parseSeconds(input) == expected)
    }

    @Test func parseSecondsRejectsGarbage() {
        #expect(URLResolver.parseSeconds("abc") == nil)
    }
}

@Suite struct FrameMathTests {
    private let minSize = CGSize(width: 160, height: 90)
    private let start = CGRect(x: 100, y: 100, width: 320, height: 180)

    @Test func rightEdgeKeepsRatioAndTop() {
        let r = FrameMath.resized(start, edge: .right, dx: 160, dy: 0, ratio: 16.0 / 9.0, minSize: minSize)
        #expect(close(r.width, 480) && close(r.height, 270))
        #expect(close(r.minX, 100) && close(r.maxY, start.maxY))
    }

    @Test func bottomLeftCornerAnchorsTopRight() {
        let r = FrameMath.resized(start, edge: [.bottom, .left], dx: -160, dy: -10, ratio: 16.0 / 9.0, minSize: minSize)
        #expect(close(r.maxX, start.maxX) && close(r.maxY, start.maxY))
        #expect(close(r.width / r.height, 16.0 / 9.0))
    }

    @Test func freeResizeRespectsMinimum() {
        let r = FrameMath.resized(start, edge: .top, dx: 0, dy: -500, ratio: nil, minSize: minSize)
        #expect(r.height == 90 && r.width == 320)
    }

    @Test func cropKeepsContentSize() {
        let cropped = FrameMath.recropped(CGRect(x: 0, y: 0, width: 640, height: 360), from: (0, 0), to: (0, 0.25))
        #expect(close(cropped.height, 270))
        let content = FrameMath.contentFrame(size: cropped.size, zoom: 1, cropH: 0, cropV: 0.25)
        #expect(close(content.height, 360) && close(content.minY, -45))
    }

    @Test func cornerPlacement() {
        let visible = CGRect(x: 0, y: 25, width: 1000, height: 600)
        let r = FrameMath.placed(CGSize(width: 200, height: 100), at: .topRight, in: visible, margin: 16)
        #expect(r.origin == CGPoint(x: 784, y: 509))
    }
}
