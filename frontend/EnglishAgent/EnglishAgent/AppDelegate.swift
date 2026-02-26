import AppKit
import SwiftUI
import KeyboardShortcuts

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("=== App launching ===")

        migrateAPIKeyFromEnvFile()

        setupFocusTracking()
        checkAccessibilityPermissions()
        setupMenuBar()
        setupKeyboardShortcut()
        registerDefaultShortcut()

        // Log the current shortcut
        if let shortcut = KeyboardShortcuts.getShortcut(for: .translateSelection) {
            debugLog("Registered shortcut: \(shortcut)")
        } else {
            debugLog("WARNING: No shortcut registered!")
        }
        debugLog("=== App ready ===")
    }

    func applicationWillTerminate(_ notification: Notification) {
        debugLog("=== App terminating ===")
    }

    // MARK: - One-time migration from .env file to Keychain

    private func migrateAPIKeyFromEnvFile() {
        guard KeychainService.getAPIKey() == nil else { return }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let envPath = appSupport.appendingPathComponent("EnglishAgent/.env").path

        guard let contents = try? String(contentsOfFile: envPath, encoding: .utf8) else { return }

        for line in contents.components(separatedBy: .newlines) {
            if line.hasPrefix("OPENROUTER_API_KEY=") {
                let key = String(line.dropFirst("OPENROUTER_API_KEY=".count)).trimmingCharacters(in: .whitespaces)
                if key != "your_api_key_here" && !key.isEmpty {
                    try? KeychainService.saveAPIKey(key)
                    try? FileManager.default.removeItem(atPath: envPath)
                    debugLog("Migrated API key from .env to Keychain")
                }
                break
            }
        }
    }

    private func setupFocusTracking() {
        // Track app focus changes so we know which app was active before our shortcut fires
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppDidChange(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // Initialize with current frontmost app (if it's not us)
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
            debugLog("Initial previousApp: \(frontmost.localizedName ?? "unknown")")
        }
    }

    @objc private func activeAppDidChange(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        // Only store if it's NOT our app - we want to track what app was active before us
        if app.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = app
            debugLog("App switched to: \(app.localizedName ?? "unknown") (PID: \(app.processIdentifier))")
        }
    }

    private func checkAccessibilityPermissions() {
        if !AccessibilityManager.shared.isAccessibilityEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                _ = AccessibilityManager.shared.requestAccessibilityPermissions()
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "English Agent")
        }

        let menu = NSMenu()

        let translateItem = NSMenuItem(title: "Translate Selection", action: #selector(translateSelection), keyEquivalent: "")
        translateItem.target = self
        menu.addItem(translateItem)

        menu.addItem(NSMenuItem.separator())

        let checkItem = NSMenuItem(title: "Check Permissions...", action: #selector(checkPermissions), keyEquivalent: "")
        checkItem.target = self
        menu.addItem(checkItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func setupKeyboardShortcut() {
        KeyboardShortcuts.onKeyDown(for: .translateSelection) { [weak self] in
            self?.translateSelection()
        }
    }

    private func registerDefaultShortcut() {
        if KeyboardShortcuts.getShortcut(for: .translateSelection) == nil {
            KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command, .shift]), for: .translateSelection)
        }
    }

    private func debugLog(_ msg: String) {
        let logFile = URL(fileURLWithPath: "/tmp/EnglishAgent_debug.log")
        let line = "[\(Date())] \(msg)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let h = try? FileHandle(forWritingTo: logFile) { h.seekToEndOfFile(); h.write(data); h.closeFile() }
            } else { try? data.write(to: logFile) }
        }
    }

    @objc private func translateSelection() {
        debugLog(">>> translateSelection() triggered!")

        // Check accessibility
        debugLog("Checking accessibility...")
        guard AccessibilityManager.shared.isAccessibilityEnabled else {
            debugLog("❌ Accessibility NOT enabled")
            FloatingPanelController.shared.showError(
                "Accessibility permission required. Please enable in System Settings > Privacy & Security > Accessibility."
            )
            AccessibilityManager.shared.checkAndPromptIfNeeded()
            return
        }
        debugLog("✓ Accessibility enabled")

        // Get the app that was active before our shortcut stole focus
        guard let sourceApp = previousApp else {
            debugLog("❌ No previous app tracked")
            let mouseLocation = NSEvent.mouseLocation
            FloatingPanelController.shared.showLoading(near: mouseLocation)
            FloatingPanelController.shared.showError("Could not determine source app. Please try again.")
            return
        }

        let pid = sourceApp.processIdentifier
        debugLog("Using previous app: \(sourceApp.localizedName ?? "unknown") (PID: \(pid))")

        // Capture text from the PREVIOUS app (not the currently focused app)
        guard let text = ClipboardService.shared.captureSelectedTextFromApp(pid), !text.isEmpty else {
            debugLog("❌ captureSelectedTextFromApp() returned nil or empty")
            let mouseLocation = NSEvent.mouseLocation
            FloatingPanelController.shared.showLoading(near: mouseLocation)
            FloatingPanelController.shared.showError("Could not capture selected text. Make sure text is selected and try again.")
            return
        }
        debugLog("✓ Got text: \(text.prefix(50))...")

        // Now show panel and perform async API call
        let mouseLocation = NSEvent.mouseLocation
        FloatingPanelController.shared.showLoading(near: mouseLocation)

        Task { @MainActor in
            do {
                let response = try await APIService.shared.translate(text: text)
                FloatingPanelController.shared.showTranslation(response.translatedText)
                let translatedText = response.translatedText
                let model = response.model
                Task.detached(priority: .utility) {
                    HistoryService.shared.save(input: text, output: translatedText, model: model)
                }
            } catch {
                FloatingPanelController.shared.showError(error.localizedDescription)
            }
        }
    }

    @objc private func checkPermissions() {
        let isEnabled = AccessibilityManager.shared.isAccessibilityEnabled

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission"
        alert.informativeText = isEnabled
            ? "Accessibility permission is enabled. The app should work correctly."
            : "Accessibility permission is NOT enabled. Click 'Open Settings' to grant permission."
        alert.alertStyle = isEnabled ? .informational : .warning

        if !isEnabled {
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                AccessibilityManager.shared.checkAndPromptIfNeeded()
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 450),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "English Agent Settings"
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow?.center()
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
