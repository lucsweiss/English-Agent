import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let translateSelection = Self("translateSelection")
}

struct SettingsView: View {
    @AppStorage("systemPrompt") private var systemPrompt = "Correct my English and give me rules so I never make these mistakes again.\n\nNo grammar jargon — explain like you're talking to a friend.\n\nFocus only on actual grammar mistakes, not on better ways to express ideas.\n\nFor each rule, show a wrong vs. right example. Keep the rules short and memorable.\n\n(If there are no mistakes, just say it is correct and don't send any rules)\n\nTEXT:"
    @AppStorage("targetLanguage") private var targetLanguage = "English"
    @AppStorage("modelName") private var modelName = "google/gemini-3-flash-preview"

    @State private var apiKey: String = ""
    @State private var apiKeySaved = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Translate Selection:")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .translateSelection)
                }
            } header: {
                Text("Keyboard Shortcut")
            }

            Section {
                HStack {
                    SecureField("sk-or-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    Button(apiKeySaved ? "Saved" : "Save") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                }

                TextField("Model", text: $modelName)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("API Configuration")
            } footer: {
                Text("Get your API key from [openrouter.ai/keys](https://openrouter.ai/keys)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                TextField("Target Language", text: $targetLanguage)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: targetLanguage) { newValue in
                        updateSystemPrompt(language: newValue)
                    }

                VStack(alignment: .leading) {
                    Text("System Prompt:")
                    TextEditor(text: $systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.3))
                }
            } header: {
                Text("Translation Settings")
            }

            Section {
                Button("Reset to Defaults") {
                    resetDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 450, height: 450)
        .onAppear {
            loadAPIKey()
        }
    }

    private func loadAPIKey() {
        if let key = KeychainService.getAPIKey() {
            apiKey = key
        }
    }

    private func saveAPIKey() {
        do {
            try KeychainService.saveAPIKey(apiKey)
            apiKeySaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                apiKeySaved = false
            }
        } catch {
            print("Failed to save API key: \(error)")
        }
    }

    private func updateSystemPrompt(language: String) {
        systemPrompt = "Correct my \(language) and give me rules so I never make these mistakes again.\n\nNo grammar jargon — explain like you're talking to a friend.\n\nFocus only on actual grammar mistakes, not on better ways to express ideas.\n\nFor each rule, show a wrong vs. right example. Keep the rules short and memorable.\n\n(If there are no mistakes, just say it is correct and don't send any rules)\n\nTEXT:"
    }

    private func resetDefaults() {
        modelName = "google/gemini-3-flash-preview"
        targetLanguage = "English"
        systemPrompt = "Correct my English and give me rules so I never make these mistakes again.\n\nNo grammar jargon — explain like you're talking to a friend.\n\nFocus only on actual grammar mistakes, not on better ways to express ideas.\n\nFor each rule, show a wrong vs. right example. Keep the rules short and memorable.\n\n(If there are no mistakes, just say it is correct and don't send any rules)\n\nTEXT:"
        KeyboardShortcuts.reset(.translateSelection)
    }
}
