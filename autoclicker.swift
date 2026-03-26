import Cocoa
import Foundation

// ── Configuration ──
var cps: Double = 20            // Clicks per second (adjustable)
var clickButton: CGMouseButton = .left
var clicking = false
var clickCount = 0

// ── Click simulation ──
func click(at point: CGPoint) {
    let downType: CGEventType = clickButton == .left ? .leftMouseDown : .rightMouseDown
    let upType: CGEventType = clickButton == .left ? .leftMouseUp : .rightMouseUp

    guard let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: clickButton),
          let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: clickButton)
    else { return }

    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
    clickCount += 1
}

func getMousePosition() -> CGPoint {
    return CGEvent(source: nil)?.location ?? .zero
}

// ── Toggle logic ──
func toggleClicking() {
    clicking.toggle()
    if clicking {
        clickCount = 0
        print("▶ STARTED — \(Int(cps)) CPS at cursor position")
        startClicking()
    } else {
        print("⏸ STOPPED — \(clickCount) clicks sent")
    }
}

func startClicking() {
    DispatchQueue.global(qos: .userInteractive).async {
        let interval = 1.0 / cps
        while clicking {
            let pos = getMousePosition()
            click(at: pos)
            Thread.sleep(forTimeInterval: interval)
        }
    }
}

// ── CGEventTap — intercepts ALL key/mouse events at the system level ──
func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    // Handle tap being disabled by the system (re-enable it)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = refcon {
            CGEvent.tapEnable(tap: Unmanaged<CFMachPort>.fromOpaque(tap).takeUnretainedValue(), enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Ctrl+Shift+A → toggle
        if keyCode == 0 /* A */ && flags.contains(.maskShift) && flags.contains(.maskControl) {
            toggleClicking()
            return nil  // Swallow the event
        }

        // Ctrl+Shift+Q → quit
        if keyCode == 12 /* Q */ && flags.contains(.maskShift) && flags.contains(.maskControl) {
            print("\n👋 Exiting autoclicker.")
            exit(0)
        }
    }

    // Mouse side buttons (otherMouseDown = buttons beyond left/right)
    if type == .otherMouseDown {
        let btn = event.getIntegerValueField(.mouseEventButtonNumber)
        if btn == 3 || btn == 4 {  // Side buttons
            toggleClicking()
            return nil  // Swallow so volume doesn't trigger
        }
    }

    return Unmanaged.passRetained(event)
}

func startEventTap() {
    let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.otherMouseDown.rawValue)

    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: eventTapCallback,
        userInfo: nil
    ) else {
        print("❌ Failed to create event tap!")
        print("   You MUST enable Accessibility access:")
        print("   System Settings → Privacy & Security → Accessibility")
        print("   Add and enable your Terminal app (Terminal / iTerm / etc)")
        exit(1)
    }

    // Pass the tap pointer to the callback so it can re-enable if needed
    let tapPtr = Unmanaged.passUnretained(tap).toOpaque()
    CGEvent.tapEnable(tap: tap, enable: true)

    // Re-create with userInfo pointing to tap
    guard let tap2 = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: eventTapCallback,
        userInfo: tapPtr
    ) else {
        print("❌ Failed to create event tap (retry)!")
        exit(1)
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap2, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap2, enable: true)
}

// ── Argument parsing ──
let args = CommandLine.arguments
for (i, arg) in args.enumerated() {
    if (arg == "--cps" || arg == "-c"), i + 1 < args.count, let val = Double(args[i + 1]) {
        cps = min(max(val, 1), 1000)
    }
    if (arg == "--right" || arg == "-r") {
        clickButton = .right
    }
}

// ── Main ──
print("""
╔══════════════════════════════════════╗
║        ⚡ AUTOCLICKER ⚡         ║
╠══════════════════════════════════════╣
║  Ctrl+Shift+A  → Start / Stop       ║
║  Mouse Side Btn → Start / Stop       ║
║  Ctrl+Shift+Q  → Quit               ║
║                                      ║
║  Speed: \(String(format: "%-4d", Int(cps))) CPS                      ║
║  Button: \(clickButton == .left ? "Left " : "Right") click                  ║
╚══════════════════════════════════════╝

⚠️  Grant Accessibility access if prompted!
    (System Settings → Privacy & Security → Accessibility)
    Add your Terminal app and toggle it ON.

Waiting for Ctrl+Shift+A or side button...
""")

startEventTap()
RunLoop.main.run()
