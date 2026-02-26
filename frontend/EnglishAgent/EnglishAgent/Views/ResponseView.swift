import SwiftUI
import MarkdownUI

struct ResponseView: View {
    @ObservedObject var controller: FloatingPanelController
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Translation")
                    .font(.headline)
                Spacer()
                Button(action: { controller.close() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            Divider()

            if controller.isLoading {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = controller.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let text = controller.translatedText {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        MarkdownText(text: text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                }

                HStack {
                    Spacer()
                    Button(action: copyTranslation) {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied" : "Copy")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 400, maxWidth: 600)
        .frame(minHeight: 150, idealHeight: 600, maxHeight: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func copyTranslation() {
        guard let text = controller.translatedText else { return }
        ClipboardService.shared.copyToClipboard(text)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}

struct MarkdownText: View {
    let text: String

    var body: some View {
        Markdown(text)
            .markdownTheme(.lightTranslation)
    }
}

extension Theme {
    static let lightTranslation = Theme()
        .text {
            ForegroundColor(.black)
            FontSize(14)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            BackgroundColor(Color(white: 0.93))
            ForegroundColor(Color(red: 0.8, green: 0.2, blue: 0.2))
        }
        .codeBlock { configuration in
            configuration.label
                .padding()
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .markdownMargin(top: 8, bottom: 8)
        }
        .blockquote { configuration in
            configuration.label
                .padding(.leading, 12)
                .overlay(
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 4),
                    alignment: .leading
                )
                .markdownMargin(top: 8, bottom: 8)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(2.4))
                }
                .markdownMargin(top: 28, bottom: 16)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.9))
                }
                .markdownMargin(top: 24, bottom: 14)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.5))
                }
                .markdownMargin(top: 22, bottom: 12)
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.2))
                }
                .markdownMargin(top: 18, bottom: 10)
        }
        .heading5 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(.em(1.05))
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading6 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(.em(0.95))
                }
                .markdownMargin(top: 14, bottom: 7)
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 10, bottom: 10)
                .relativeLineSpacing(.em(0.35))
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 6)
        }
        .list { configuration in
            configuration.label
                .markdownMargin(top: 12, bottom: 12)
        }
}

