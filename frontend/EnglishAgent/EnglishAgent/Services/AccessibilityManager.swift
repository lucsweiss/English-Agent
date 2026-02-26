import ApplicationServices
import os.log

class AccessibilityManager {
    static let shared = AccessibilityManager()
    private let logger = Logger(subsystem: "com.englishagent.app", category: "Accessibility")

    private init() {}

    var isAccessibilityEnabled: Bool {
        let trusted = AXIsProcessTrusted()
        logger.debug("Accessibility check: \(trusted)")
        return trusted
    }

    func requestAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        logger.info("Accessibility permission requested, result: \(trusted)")
        return trusted
    }

    func checkAndPromptIfNeeded() {
        if !isAccessibilityEnabled {
            logger.warning("Accessibility not enabled, prompting user")
            _ = requestAccessibilityPermissions()
        }
    }
}
