// 밧줄을 태우지 마라 (Don't Burn the Rope): when you stop touching the mouse and keyboard, a rope starts burning across the screen.
// Touch anything and it disappears. Transparent, click-through, no calibration.
import Cocoa
import WebKit

let defaults = UserDefaults.standard

import IOKit

/// HID idle time from the IOHIDSystem registry entry (works without a window-server session).
func hidIdleSeconds() -> Double {
    var it: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &it) == KERN_SUCCESS else { return -1 }
    defer { IOObjectRelease(it) }
    let e = IOIteratorNext(it); guard e != 0 else { return -1 }
    defer { IOObjectRelease(e) }
    var props: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(e, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let d = props?.takeRetainedValue() as? [String: Any], let n = d["HIDIdleTime"] as? NSNumber else { return -1 }
    return n.doubleValue / 1e9
}

/// Seconds since the last mouse, keyboard, scroll or trackpad event (no special permission needed).
func idleSeconds() -> Double {
    let cg = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    let hid = hidIdleSeconds()
    return hid >= 0 ? hid : cg
}

final class App: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    var win: NSWindow!
    var web: WKWebView!
    var status: NSStatusItem!
    var ready = false
    var showing = false
    var paused = false
    var threshold: Double { defaults.object(forKey: "idleSeconds") as? Double ?? 10 }

    func applicationDidFinishLaunching(_ n: Notification) {
        win = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .screenSaver
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        win.isReleasedWhenClosed = false
        fitScreen()

        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "rope")
        cfg.mediaTypesRequiringUserActionForPlayback = []
        web = WKWebView(frame: win.contentView!.bounds, configuration: cfg)
        web.autoresizingMask = [.width, .height]
        web.setValue(false, forKey: "drawsBackground")
        win.contentView!.addSubview(web)
        let html = Bundle.main.url(forResource: "rope", withExtension: "html")!
        web.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        win.orderFrontRegardless()   // stays on screen but fully transparent until idle

        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "flame", accessibilityDescription: "밧줄을 태우지 마라")
        status.button?.image?.isTemplate = true
        rebuildMenu()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.fitScreen() }
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
    }

    func fitScreen() {
        let s = NSScreen.main ?? NSScreen.screens[0]
        win.setFrame(s.frame, display: true)
    }

    func tick() {
        guard ready else { return }
        let idle = idleSeconds()
        if !showing && !paused && idle >= threshold {
            showing = true
            fitScreen()
            win.orderFrontRegardless()
            js("ropeShow()")
        } else if showing && (idle < 0.3 || paused) {
            showing = false
            js("ropeHide()")
        }
    }

    func rebuildMenu() {
        let m = NSMenu()
        let head = NSMenuItem(title: "밧줄을 태우지 마라", action: nil, keyEquivalent: ""); head.isEnabled = false; m.addItem(head)
        m.addItem(.separator())
        for s in [3.0, 10, 30, 60, 300] {
            let t = s < 60 ? "\(Int(s))초 뒤" : "\(Int(s / 60))분 뒤"
            let i = NSMenuItem(title: t, action: #selector(setIdle(_:)), keyEquivalent: ""); i.target = self; i.tag = Int(s)
            i.state = threshold == s ? .on : .off; m.addItem(i)
        }
        m.addItem(.separator())
        let snd = NSMenuItem(title: "소리", action: #selector(toggleSound), keyEquivalent: ""); snd.target = self
        snd.state = defaults.bool(forKey: "sound") ? .on : .off; m.addItem(snd)
        let pz = NSMenuItem(title: "잠시 끄기", action: #selector(togglePause), keyEquivalent: ""); pz.target = self
        pz.state = paused ? .on : .off; m.addItem(pz)
        m.addItem(.separator())
        let q = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q"); q.target = self; m.addItem(q)
        status.menu = m
    }

    @objc func setIdle(_ s: NSMenuItem) { defaults.set(Double(s.tag), forKey: "idleSeconds"); rebuildMenu() }
    @objc func toggleSound() { defaults.set(!defaults.bool(forKey: "sound"), forKey: "sound"); js("ropeSetup({sound:\(defaults.bool(forKey: "sound"))})"); rebuildMenu() }
    @objc func togglePause() { paused.toggle(); rebuildMenu() }
    @objc func quit() { NSApp.terminate(nil) }

    func js(_ s: String) { web.evaluateJavaScript(s, completionHandler: nil) }

    func userContentController(_ c: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let d = msg.body as? [String: Any], d["type"] as? String == "ready" else { return }
        ready = true
        js("ropeSetup({sound:\(defaults.bool(forKey: "sound"))})")
    }
}

if CommandLine.arguments.contains("--idle") {   // test hook
    for _ in 0..<10 { print(String(format: "idle %.2f s (cg %.2f, hid %.2f)", idleSeconds(), CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!), hidIdleSeconds())); Thread.sleep(forTimeInterval: 0.5) }
    exit(0)
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
