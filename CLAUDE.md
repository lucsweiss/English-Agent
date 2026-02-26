# English Agent App

A macOS menu bar app for instant text translation via LLM. Press **Cmd+Shift+T** to translate selected text and display the result in a floating overlay window. Calls the OpenRouter API directly from Swift — no backend server needed.

## Project Structure

```
English Agent App/
├── .gitignore
├── CLAUDE.md
├── DEPLOYMENT.md               # Deployment/packaging guide
├── QUICKSTART.md               # Quick start guide
├── test_translations.html      # Test page with multi-language text
│
├── frontend/EnglishAgent/      # Swift macOS app
│   ├── EnglishAgent.xcodeproj
│   └── EnglishAgent/
│       ├── EnglishAgentApp.swift          # @main entry
│       ├── AppDelegate.swift              # Menu bar + shortcuts
│       ├── FloatingPanel.swift            # NSPanel overlay
│       ├── EnglishAgent.entitlements      # App entitlements
│       ├── Info.plist                     # LSUIElement=YES
│       ├── Views/
│       │   ├── ResponseView.swift         # Translation display
│       │   ├── SettingsView.swift         # Config UI
│       │   └── LoadingView.swift
│       └── Services/
│           ├── APIService.swift           # Direct OpenRouter API client
│           ├── KeychainService.swift      # Secure API key storage
│           ├── ClipboardService.swift     # Text capture
│           ├── HistoryService.swift      # Translation history (JSON + markdown)
│           └── AccessibilityManager.swift # Accessibility permissions
```

## Running the App

Build with Xcode or:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project frontend/EnglishAgent/EnglishAgent.xcodeproj -scheme EnglishAgent build
```

App location after build:
```
~/Library/Developer/Xcode/DerivedData/EnglishAgent-*/Build/Products/Debug/EnglishAgent.app
```

### First Launch Setup
1. Open the app (appears in menu bar)
2. Go to Settings (Cmd+,)
3. Enter your OpenRouter API key (stored securely in macOS Keychain)
4. Select text anywhere, press Cmd+Shift+T to translate

## Architecture

The app calls the OpenRouter API (`https://openrouter.ai/api/v1/chat/completions`) directly from Swift using `URLSession`. No backend server is needed.

- **API key**: Stored in macOS Keychain via `KeychainService.swift`
- **Model & prompts**: Stored in `UserDefaults` via `@AppStorage`
- **Default model**: `google/gemini-3-flash-preview`

## Tech Stack
- **Frontend**: Swift, SwiftUI, AppKit, KeyboardShortcuts package
- **API**: OpenRouter (direct HTTPS calls, no backend proxy)
- **Markdown**: MarkdownUI package for rendering translations
- **Deployment target**: macOS 13.0+

## UI Notes

- **Floating panel background**: Uses a plain `Color.white` SwiftUI background with `RoundedRectangle` clip shape in `ResponseView.swift`. Do NOT use `NSVisualEffectView` for the panel background — its material system always renders as translucent gray and overrides any `backgroundColor` set on the layer. The panel itself (`FloatingPanel.swift`) has `backgroundColor = .white` with `isOpaque = false` for rounded corner compositing.

## Life System Integration

This project's notes, todos, bugs, and docs live in the Life system at:
`/Users/lucasweiss/Downloads/Life/03-projects/english-agent-app/`

**Before creating or modifying any files there, you MUST read:**
1. `/Users/lucasweiss/Downloads/Life/CLAUDE.md` — operating instructions and rules
2. `/Users/lucasweiss/Downloads/Life/_templates.md` — note formats and frontmatter specs
3. `/Users/lucasweiss/Downloads/Life/03-projects/english-agent-app/_context.md` — project state

Follow those rules exactly. Every file you create in the Life system must comply with its conventions.
