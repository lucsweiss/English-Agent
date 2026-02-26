import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let translateSelection = Self("translateSelection")
}

struct SettingsView: View {
    @AppStorage("systemPrompt") private var systemPrompt = "Translate the following text to English. Only output the translation, nothing else."
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
        systemPrompt = "Translate the following text to \(language). Only output the translation, nothing else."
    }

    private func resetDefaults() {
        modelName = "google/gemini-3-flash-preview"
        targetLanguage = "English"
        systemPrompt = "Translate the following text to English. Only output the translation, nothing else."
        KeyboardShortcuts.reset(.translateSelection)
    }
}
