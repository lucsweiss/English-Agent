# English Agent

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Instant translation from your menu bar. Select any text, press **Cmd+Shift+T**, and get a translation in a floating overlay — powered by any LLM via [OpenRouter](https://openrouter.ai).

<!-- ![English Agent screenshot](screenshot.png) -->

## Features

- **Global shortcut** — Translate selected text from any app with Cmd+Shift+T
- **Floating overlay** — Results appear in a non-intrusive panel near your cursor
- **Any LLM model** — Uses OpenRouter to access GPT-4, Gemini, Claude, Llama, and more
- **Configurable** — Change target language, model, and system prompt in Settings
- **Markdown rendering** — Rich formatting for structured translations
- **Secure** — API key stored in macOS Keychain, never in plain text
- **Translation history** — Logs saved as JSON for review or analysis
- **Lightweight** — Runs as a menu bar app with zero dock clutter

## How It Works

1. Select text in any application
2. Press **Cmd+Shift+T** (customizable)
3. The app captures the selected text via macOS Accessibility APIs
4. Sends it to the OpenRouter API with your configured prompt
5. Displays the translated result in a floating panel

No backend server — the app calls the API directly from Swift.

## Installation

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 14.0+ (to build from source)
- An [OpenRouter API key](https://openrouter.ai/keys)

### Build from Source

```bash
git clone https://github.com/lucsweiss/English-Agent.git
cd English-Agent
xcodebuild -project frontend/EnglishAgent/EnglishAgent.xcodeproj -scheme EnglishAgent build
```

The built app will be at:
```
~/Library/Developer/Xcode/DerivedData/EnglishAgent-*/Build/Products/Debug/EnglishAgent.app
```

Or open `frontend/EnglishAgent/EnglishAgent.xcodeproj` in Xcode and press Cmd+R.

### First Launch

1. Launch the app — it appears as a speech bubble icon in your menu bar
2. **Grant Accessibility permission** when prompted (required to read selected text)
3. Open **Settings** (click menu bar icon > Settings, or Cmd+,)
4. Enter your **OpenRouter API key**
5. Select text anywhere and press **Cmd+Shift+T**

> **Note:** Since the app is not notarized, you may need to right-click > Open on first launch to bypass Gatekeeper.

## Configuration

All settings are accessible from the menu bar icon > Settings:

| Setting | Default | Description |
|---------|---------|-------------|
| API Key | — | Your OpenRouter API key (stored in Keychain) |
| Model | `google/gemini-3-flash-preview` | Any model available on [OpenRouter](https://openrouter.ai/models) |
| Target Language | English | Language to translate into |
| System Prompt | Auto-generated | Customizable instruction sent to the LLM |
| Keyboard Shortcut | Cmd+Shift+T | Customizable via the recorder |

## Project Structure

```
frontend/EnglishAgent/
├── EnglishAgent.xcodeproj
└── EnglishAgent/
    ├── EnglishAgentApp.swift          # @main entry point
    ├── AppDelegate.swift              # Menu bar setup, shortcut handling
    ├── FloatingPanel.swift            # NSPanel overlay + controller
    ├── Views/
    │   ├── ResponseView.swift         # Translation display with Markdown
    │   ├── SettingsView.swift         # Settings UI
    │   └── LoadingView.swift          # Loading spinner
    └── Services/
        ├── APIService.swift           # OpenRouter API client
        ├── KeychainService.swift      # Keychain CRUD for API key
        ├── ClipboardService.swift     # Text capture via Accessibility
        ├── HistoryService.swift       # Translation history logging
        └── AccessibilityManager.swift # Permission management
```

## Dependencies

Managed via Swift Package Manager in the Xcode project:

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Global keyboard shortcut registration
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) — Markdown rendering in SwiftUI

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
