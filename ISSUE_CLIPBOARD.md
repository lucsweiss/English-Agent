# Issue: Clipboard Text Capture Not Working

## Problem
When user presses ⌘+Shift+T, the app shows "No text selected. Please select some text first" even when text IS selected.

## Root Cause
The `ClipboardService.swift` attempts to:
1. Simulate ⌘+C keystroke using CGEvent
2. Read the copied text from NSPasteboard
3. This requires **Accessibility permissions** which may not be working

## What's Been Verified Working
- Backend API: ✅ Translations work perfectly via curl
- Menu bar icon: ✅ Appears correctly
- Keyboard shortcut: ✅ Triggers (KeyboardShortcuts package works)
- Floating panel: ✅ Shows up with loading/error states
- Settings window: ✅ Opens and saves preferences

## What's NOT Working
- `ClipboardService.simulateCopy()` - CGEvent keystroke simulation fails silently
- The pasteboard.changeCount never changes after simulateCopy()

## Accessibility Permission Status
The app needs to be in: **System Settings → Privacy & Security → Accessibility**

Commands to check/reset:
```bash
# Reset permissions (requires re-granting)
tccutil reset Accessibility com.englishagent.app

# Check if app is requesting permissions properly
# Look in Console.app for "EnglishAgent" and "accessibility" messages
```

## Code Location
`frontend/EnglishAgent/EnglishAgent/Services/ClipboardService.swift`

## Approaches Tried
1. **CGEventSource .hidSystemState** → didn't work
2. **CGEventSource .combinedSessionState** → didn't work
3. **Different event taps**: `.cghidEventTap`, `.cgSessionEventTap` → neither worked
4. **Increased delays**: 100ms, 500ms between events → didn't help
5. **Multiple retry attempts**: polling pasteboard 5 times → still fails

## Potential Solutions to Try

### 1. Use NSAppleScript instead of CGEvent
```swift
func simulateCopyViaAppleScript() {
    let script = NSAppleScript(source: """
        tell application "System Events"
            keystroke "c" using command down
        end tell
    """)
    var error: NSDictionary?
    script?.executeAndReturnError(&error)
}
```
Note: Also requires accessibility permissions but might work differently.

### 2. Check AXIsProcessTrusted()
```swift
import ApplicationServices

func checkAccessibility() -> Bool {
    let trusted = AXIsProcessTrusted()
    if !trusted {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    return trusted
}
```
Call this at app launch to prompt for permissions.

### 3. Use Accessibility API to read selection directly
Instead of simulating copy, use AX APIs to read the focused element's selected text:
```swift
func getSelectedTextViaAccessibility() -> String? {
    let systemWideElement = AXUIElementCreateSystemWide()
    var focusedElement: AnyObject?
    AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

    if let element = focusedElement {
        var selectedText: AnyObject?
        AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
        return selectedText as? String
    }
    return nil
}
```

### 4. Entitlements Issue
The app may need proper entitlements. Check `EnglishAgent.entitlements`:
- Currently has `com.apple.security.app-sandbox = false`
- Might need explicit accessibility entitlement for distribution

### 5. Code Signing
Ad-hoc signed apps sometimes have issues with accessibility. Try:
```bash
codesign --force --deep --sign - /path/to/EnglishAgent.app
```

## Debug Steps
1. Add logging to ClipboardService to see if CGEvent objects are nil
2. Check Console.app for any permission denied messages
3. Verify app appears in Accessibility list after first run
4. Try running from Xcode with debugger to catch any silent failures

## Quick Test
After any fix, test with:
1. Open `test_translations.html` in browser
2. Select Portuguese text: "Olá! Como você está?"
3. Press ⌘+Shift+T
4. Should see floating panel with "Hello! How are you?"
