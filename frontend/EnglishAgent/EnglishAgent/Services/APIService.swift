import Foundation

// MARK: - OpenRouter Request/Response Models

private struct OpenRouterRequest: Encodable {
    let model: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct OpenRouterResponse: Decodable {
    let choices: [Choice]
    let model: String?

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

private struct OpenRouterErrorResponse: Decodable {
    let error: ErrorDetail?

    struct ErrorDetail: Decodable {
        let message: String?
        let code: Int?
    }
}

// MARK: - Public Response Model

struct TranslateResponse {
    let translatedText: String
    let model: String
}

// MARK: - Errors

enum APIServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not configured. Please add your OpenRouter API key in Settings."
        case .invalidURL:
            return "Invalid API URL"
        case .noData:
            return "No data received from API"
        case .decodingError:
            return "Failed to parse API response"
        case .serverError(let message):
            return "API error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - API Service

actor APIService {
    static let shared = APIService()

    private let openRouterURL = "https://openrouter.ai/api/v1/chat/completions"
    private let defaultModel = "google/gemini-3-flash-preview"

    private init() {}

    func translate(text: String, systemPrompt: String? = nil) async throws -> TranslateResponse {
        guard let apiKey = KeychainService.getAPIKey(), !apiKey.isEmpty else {
            throw APIServiceError.missingAPIKey
        }

        let model = UserDefaults.standard.string(forKey: "modelName") ?? defaultModel
        let prompt = systemPrompt
            ?? UserDefaults.standard.string(forKey: "systemPrompt")
            ?? "Correct my English and give me rules so I never make these mistakes again.\n\nNo grammar jargon — explain like you're talking to a friend.\n\nFocus only on actual grammar mistakes, not on better ways to express ideas.\n\nFor each rule, show a wrong vs. right example. Keep the rules short and memorable.\n\n(If there are no mistakes, just say it is correct and don't send any rules)\n\nTEXT:"

        guard let url = URL(string: openRouterURL) else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://english-agent-app.local", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("English Agent App", forHTTPHeaderField: "X-Title")

        let openRouterRequest = OpenRouterRequest(
            model: model,
            messages: [
                .init(role: "system", content: prompt),
                .init(role: "user", content: text),
            ]
        )
        request.httpBody = try JSONEncoder().encode(openRouterRequest)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIServiceError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.noData
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data),
               let message = errorResponse.error?.message {
                throw APIServiceError.serverError(message)
            }
            throw APIServiceError.serverError("HTTP \(httpResponse.statusCode)")
        }

        let openRouterResponse: OpenRouterResponse
        do {
            openRouterResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        } catch {
            throw APIServiceError.decodingError
        }

        guard let firstChoice = openRouterResponse.choices.first else {
            throw APIServiceError.serverError("No response choices returned")
        }

        return TranslateResponse(
            translatedText: firstChoice.message.content,
            model: openRouterResponse.model ?? model
        )
    }
}
