import AppKit
import ApplicationServices
import Carbon
import os.log

class ClipboardService {
    static let shared = ClipboardService()
    private let logger = Logger(subsystem: "com.englishagent.app", category: "ClipboardService")
    private let logFile = URL(fileURLWithPath: "/tmp/EnglishAgent_debug.log")

    private init() {}

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        print(line, terminator: "")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    // MARK: - AXError Debugging Helpers

    /// Returns a human-readable description for AXError codes
    private func describeAXError(_ error: AXError) -> String {
        switch error {
        case .success:
            return "Success (0)"
        case .failure:
            return "Failure (-25200) - Generic failure"
        case .illegalArgument:
            return "IllegalArgument (-25201) - Invalid argument passed"
        case .invalidUIElement:
            return "InvalidUIElement (-25202) - Element is invalid or destroyed"
        case .invalidUIElementObserver:
            return "InvalidUIElementObserver (-25203) - Observer is invalid"
        case .cannotComplete:
            return "CannotComplete (-25204) - Request cannot be completed"
        case .attributeUnsupported:
            return "AttributeUnsupported (-25205) - Attribute not supported by element"
        case .actionUnsupported:
            return "ActionUnsupported (-25206) - Action not supported by element"
        case .notificationUnsupported:
            return "NotificationUnsupported (-25207) - Notification not supported"
        case .notImplemented:
            return "NotImplemented (-25208) - App doesn't implement this feature"
        case .notificationAlreadyRegistered:
            return "NotificationAlreadyRegistered (-25209)"
        case .notificationNotRegistered:
            return "NotificationNotRegistered (-25210)"
        case .apiDisabled:
            return "APIDisabled (-25211) - ACCESSIBILITY NOT ENABLED in System Settings!"
        case .noValue:
            return "NoValue (-25212) - No text is currently selected"
        case .parameterizedAttributeUnsupported:
            return "ParameterizedAttributeUnsupported (-25213)"
        case .notEnoughPrecision:
            return "NotEnoughPrecision (-25214)"
        @unknown default:
            return "Unknown error (rawValue: \(error.rawValue))"
        }
    }

    /// Logs detailed diagnostic information about the current accessibility state
    private func logAccessibilityDiagnostics() {
        log("[EnglishAgent] === ACCESSIBILITY DIAGNOSTICS ===")

        // Check if accessibility is enabled at the system level
        let isAccessibilityEnabled = AXIsProcessTrusted()
        log("[EnglishAgent] AXIsProcessTrusted(): \(isAccessibilityEnabled)")

        if !isAccessibilityEnabled {
            log("[EnglishAgent] ⚠️ ACCESSIBILITY NOT ENABLED")
        }

        // Log the current process info
        let processInfo = ProcessInfo.processInfo
        log("[EnglishAgent] Process: \(processInfo.processName) (PID: \(processInfo.processIdentifier))")

        // Log the bundle location
        if let bundlePath = Bundle.main.bundlePath as String? {
            log("[EnglishAgent] App location: \(bundlePath)")
            if bundlePath.contains("DerivedData") {
                log("[EnglishAgent] ⚠️ Running from DerivedData!")
            }
        }

        log("[EnglishAgent] =================================")
    }

    /// Capture selected text from a specific app by PID
    /// This is the key fix - we query the PREVIOUS app, not the currently focused one
    func captureSelectedTextFromApp(_ pid: pid_t) -> String? {
        log("[EnglishAgent] >>> captureSelectedTextFromApp(pid: \(pid)) called")
        NSLog("[EnglishAgent] >>> captureSelectedTextFromApp(pid: \(pid)) called")

        // Log detailed diagnostics for debugging
        logAccessibilityDiagnostics()

        // Check accessibility first
        guard AccessibilityManager.shared.isAccessibilityEnabled else {
            log("[EnglishAgent] ❌ AccessibilityManager reports permissions not granted")
            NSLog("[EnglishAgent] ❌ AccessibilityManager reports permissions not granted")
            return nil
        }

        log("[EnglishAgent] ✓ AccessibilityManager reports permissions are granted")

        // Method 1: Try Accessibility API (works for most native apps like Notion)
        if let text = getSelectedTextFromApp(pid) {
            return text
        }

        // Method 2: For browsers and apps with poor accessibility support,
        // re-activate the app and simulate Cmd+C
        log("[EnglishAgent] Trying clipboard fallback for app with PID \(pid)...")
        if let text = captureViaClipboardFromApp(pid) {
            return text
        }

        log("[EnglishAgent] ❌ Could not get selected text from app with PID \(pid)")
        return nil
    }

    /// Fallback: Re-activate the source app, simulate Cmd+C, read clipboard
    private func captureViaClipboardFromApp(_ pid: pid_t) -> String? {
        log("[EnglishAgent] --- Clipboard fallback for PID \(pid) ---")

        guard let app = NSRunningApplication(processIdentifier: pid) else {
            log("[EnglishAgent] ❌ Could not find app with PID \(pid)")
            return nil
        }

        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        let changeCountBefore = pasteboard.changeCount

        // Re-activate the source app
        log("[EnglishAgent] Re-activating \(app.localizedName ?? "app")...")
        app.activate(options: [])

        // Small delay for app to become active
        Thread.sleep(forTimeInterval: 0.05)

        // Simulate Cmd+C
        log("[EnglishAgent] Simulating Cmd+C...")
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            log("[EnglishAgent] ❌ Failed to create CGEventSource")
            restoreClipboard(previousContents)
            return nil
        }

        guard let cDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let cUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false) else {
            log("[EnglishAgent] ❌ Failed to create CGEvent")
            restoreClipboard(previousContents)
            return nil
        }

        cDown.flags = .maskCommand
        cUp.flags = .maskCommand

        cDown.post(tap: .cgAnnotatedSessionEventTap)
        cUp.post(tap: .cgAnnotatedSessionEventTap)

        // Wait for copy to complete and check clipboard
        for i in 0..<15 {
            Thread.sleep(forTimeInterval: 0.03)

            if pasteboard.changeCount != changeCountBefore {
                if let text = pasteboard.string(forType: .string), !text.isEmpty {
                    log("[EnglishAgent] ✓ Clipboard fallback SUCCESS after \(i+1) checks! Got \(text.count) chars")
                    restoreClipboard(previousContents)
                    return text
                }
            }
        }

        log("[EnglishAgent] ❌ Clipboard fallback failed - clipboard unchanged")
        restoreClipboard(previousContents)
        return nil
    }

    /// Synchronous text capture - call this IMMEDIATELY when shortcut fires, before any async work
    /// This is critical because focus can shift during async operations
    func captureSelectedTextSync() -> String? {
        log("[EnglishAgent] >>> captureSelectedTextSync() called")
        NSLog("[EnglishAgent] >>> captureSelectedTextSync() called")

        // Log detailed diagnostics for debugging
        logAccessibilityDiagnostics()

        // Check accessibility first
        guard AccessibilityManager.shared.isAccessibilityEnabled else {
            log("[EnglishAgent] ❌ AccessibilityManager reports permissions not granted")
            NSLog("[EnglishAgent] ❌ AccessibilityManager reports permissions not granted")
            return nil
        }

        log("[EnglishAgent] ✓ AccessibilityManager reports permissions are granted")

        // Try Accessibility API (this is synchronous and must be called before focus shifts)
        if let text = getSelectedTextViaAccessibility() {
            return text
        }

        log("[EnglishAgent] ❌ Accessibility API failed - focus may have shifted")
        return nil
    }

    func captureSelectedText() async -> String? {
        log("[EnglishAgent] >>> captureSelectedText() called")
        NSLog("[EnglishAgent] >>> captureSelectedText() called")

        // Log detailed diagnostics for debugging
        logAccessibilityDiagnostics()

        // Check accessibility first
        guard AccessibilityManager.shared.isAccessibilityEnabled else {
            log("[EnglishAgent] ❌ AccessibilityManager reports permissions not granted")
            NSLog("[EnglishAgent] ❌ AccessibilityManager reports permissions not granted")
            return nil
        }

        log("[EnglishAgent] ✓ AccessibilityManager reports permissions are granted")

        // Method 1: Try Accessibility API (most reliable)
        if let text = getSelectedTextViaAccessibility() {
            return text
        }

        // Method 2: Try CGEvent simulation
        if let text = await getSelectedTextViaCopy() {
            return text
        }

        // Method 3: Try AppleScript
        if let text = await getSelectedTextViaAppleScript() {
            return text
        }

        log("[EnglishAgent] ========================================")
        log("[EnglishAgent] ❌ ALL TEXT CAPTURE METHODS FAILED")
        log("[EnglishAgent] ========================================")
        return nil
    }

    // MARK: - Primary Method: Get selected text from specific app by PID

    private func getSelectedTextFromApp(_ pid: pid_t) -> String? {
        log("[EnglishAgent] --- Getting selected text from app PID: \(pid) ---")

        // Create AXUIElement for the specific app (not the currently focused one!)
        let appElement = AXUIElementCreateApplication(pid)

        // Log app info
        var appTitle: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXTitleAttribute as CFString, &appTitle) == .success {
            log("[EnglishAgent]   ✓ Target app: \(appTitle as? String ?? "unknown")")
        }

        // Try Method A: Get focused UI element directly from app
        log("[EnglishAgent] Method A: Getting focused UI element from app...")
        var focusedElement: AnyObject?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        if result == .success, let element = focusedElement {
            log("[EnglishAgent]   ✓ Got focused element directly")
            if let text = getSelectedTextFromElement(element as! AXUIElement) {
                return text
            }
        } else {
            log("[EnglishAgent]   Method A failed: \(self.describeAXError(result))")
        }

        // Try Method B: Get the focused/main window, then find focused element there
        log("[EnglishAgent] Method B: Getting focused window...")
        var focusedWindow: AnyObject?
        result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        if result == .success, let window = focusedWindow {
            log("[EnglishAgent]   ✓ Got focused window")

            // Try to get focused element from the window
            var windowFocusedElement: AnyObject?
            let windowResult = AXUIElementCopyAttributeValue(
                window as! AXUIElement,
                kAXFocusedUIElementAttribute as CFString,
                &windowFocusedElement
            )

            if windowResult == .success, let element = windowFocusedElement {
                log("[EnglishAgent]   ✓ Got focused element from window")
                if let text = getSelectedTextFromElement(element as! AXUIElement) {
                    return text
                }
            }
        } else {
            log("[EnglishAgent]   Method B failed: \(self.describeAXError(result))")
        }

        // Try Method C: Get all windows and check each for selected text
        log("[EnglishAgent] Method C: Checking all windows...")
        var windows: AnyObject?
        result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windows
        )

        if result == .success, let windowArray = windows as? [AXUIElement] {
            log("[EnglishAgent]   Found \(windowArray.count) windows")
            for (index, window) in windowArray.enumerated() {
                log("[EnglishAgent]   Checking window \(index)...")
                if let text = findSelectedTextInElement(window, depth: 0, maxDepth: 5) {
                    return text
                }
            }
        }

        log("[EnglishAgent] ❌ All methods failed to get selected text")
        return nil
    }

    private func getSelectedTextFromElement(_ element: AXUIElement) -> String? {
        var elementRole: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &elementRole) == .success {
            log("[EnglishAgent]     Element role: \(elementRole as? String ?? "unknown")")
        }

        var selectedText: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        if result == .success, let text = selectedText as? String, !text.isEmpty {
            log("[EnglishAgent]     ✓ SUCCESS! Captured \(text.count) chars")
            return text
        }

        log("[EnglishAgent]     No selected text: \(self.describeAXError(result))")
        return nil
    }

    private func findSelectedTextInElement(_ element: AXUIElement, depth: Int, maxDepth: Int) -> String? {
        if depth > maxDepth { return nil }

        // Try to get selected text from this element
        var selectedText: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText) == .success,
           let text = selectedText as? String, !text.isEmpty {
            log("[EnglishAgent]     ✓ Found selected text at depth \(depth)")
            return text
        }

        // Check children
        var children: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let childArray = children as? [AXUIElement] {
            for child in childArray {
                if let text = findSelectedTextInElement(child, depth: depth + 1, maxDepth: maxDepth) {
                    return text
                }
            }
        }

        return nil
    }

    // MARK: - Method 1: Accessibility API (Primary)

    private func getSelectedTextViaAccessibility() -> String? {
        log("[EnglishAgent] --- Method 1: Accessibility API ---")

        let systemWideElement = AXUIElementCreateSystemWide()

        // Step 1: Get the focused application
        log("[EnglishAgent] Step 1: Getting focused application...")
        var focusedApp: AnyObject?
        var result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        log("[EnglishAgent]   Result: \(self.describeAXError(result))")

        guard result == .success, let app = focusedApp else {
            log("[EnglishAgent] ❌ Failed to get focused application")
            if result == .apiDisabled {
                log("[EnglishAgent]    FIX: Remove and re-add app in Accessibility settings")
            }
            return nil
        }

        // Log info about the focused app
        let appElement = app as! AXUIElement
        var appTitle: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXTitleAttribute as CFString, &appTitle) == .success {
            log("[EnglishAgent]   ✓ Focused app: \(appTitle as? String ?? "unknown")")
        }

        // Step 2: Get the focused UI element within the app
        log("[EnglishAgent] Step 2: Getting focused UI element...")
        var focusedElement: AnyObject?
        result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        log("[EnglishAgent]   Result: \(self.describeAXError(result))")

        guard result == .success, let element = focusedElement else {
            log("[EnglishAgent] ❌ Failed to get focused UI element")
            return nil
        }

        // Log info about the focused element
        let uiElement = element as! AXUIElement
        var elementRole: AnyObject?
        if AXUIElementCopyAttributeValue(uiElement, kAXRoleAttribute as CFString, &elementRole) == .success {
            log("[EnglishAgent]   ✓ Element role: \(elementRole as? String ?? "unknown")")
        }

        // Step 3: Get the selected text from the focused element
        log("[EnglishAgent] Step 3: Getting selected text...")
        var selectedText: AnyObject?
        result = AXUIElementCopyAttributeValue(
            uiElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        log("[EnglishAgent]   Result: \(self.describeAXError(result))")

        if result == .success, let text = selectedText as? String {
            if text.isEmpty {
                log("[EnglishAgent]   ⚠️ Selected text is empty")
                return nil
            }
            log("[EnglishAgent]   ✓ SUCCESS! Captured \(text.count) chars")
            return text
        }

        log("[EnglishAgent] ❌ Accessibility API method failed")
        return nil
    }

    // MARK: - Method 2: CGEvent Copy Simulation (Fallback)

    private func getSelectedTextViaCopy() async -> String? {
        log("[EnglishAgent] --- Method 2: CGEvent Copy Simulation ---")

        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        let changeCountAfterClear = pasteboard.changeCount

        // Small delay before simulating copy
        try? await Task.sleep(nanoseconds: 30_000_000) // 30ms

        // Create event source with private state for better isolation
        guard let source = CGEventSource(stateID: .privateState) else {
            log("[EnglishAgent] ❌ Failed to create CGEventSource")
            restoreClipboard(previousContents)
            return nil
        }

        guard let cDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let cUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false) else {
            log("[EnglishAgent] ❌ Failed to create CGEvent")
            restoreClipboard(previousContents)
            return nil
        }

        cDown.flags = .maskCommand
        cUp.flags = .maskCommand

        cDown.post(tap: .cghidEventTap)
        cUp.post(tap: .cghidEventTap)
        log("[EnglishAgent]   Posted Cmd+C keystroke")

        // Poll for clipboard change
        for i in 0..<10 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            if pasteboard.changeCount != changeCountAfterClear {
                if let text = pasteboard.string(forType: .string), !text.isEmpty {
                    log("[EnglishAgent]   ✓ CGEvent SUCCESS after \(i+1) attempts")
                    restoreClipboard(previousContents)
                    return text
                }
            }
        }

        log("[EnglishAgent] ❌ CGEvent method failed - clipboard unchanged")
        restoreClipboard(previousContents)
        return nil
    }

    // MARK: - Method 3: AppleScript (Last Resort)

    private func getSelectedTextViaAppleScript() async -> String? {
        log("[EnglishAgent] --- Method 3: AppleScript ---")

        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()

        let script = NSAppleScript(source: """
            tell application "System Events"
                keystroke "c" using command down
            end tell
        """)

        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        if let error = error {
            log("[EnglishAgent] ❌ AppleScript error: \(error)")
            if let errorNumber = error[NSAppleScript.errorNumber] as? Int, errorNumber == -1743 {
                log("[EnglishAgent]    FIX: Enable Automation permission for System Events")
            }
            restoreClipboard(previousContents)
            return nil
        }

        // Wait for copy to complete
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            log("[EnglishAgent]   ✓ AppleScript SUCCESS")
            restoreClipboard(previousContents)
            return text
        }

        log("[EnglishAgent] ❌ AppleScript method failed - clipboard empty")
        restoreClipboard(previousContents)
        return nil
    }

    // MARK: - Helpers

    private func restoreClipboard(_ previousContents: String?) {
        if let previous = previousContents {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
