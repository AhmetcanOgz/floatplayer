import AppKit

let arguments = CommandLine.arguments
let delegate: NSApplicationDelegate
if let i = arguments.firstIndex(of: "--check"), i + 1 < arguments.count {
    let referer = arguments.firstIndex(of: "--referer").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
    delegate = EmbedChecker(input: arguments[i + 1], sendReferer: !arguments.contains("--no-referer"), referer: referer, layout: arguments.contains("--layout"))
} else {
    delegate = AppDelegate()
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
