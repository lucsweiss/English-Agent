import Foundation

struct TranslationEntry: Codable {
    let id: UUID
    let timestamp: Date
    let inputText: String
    let translatedText: String
    let model: String
}

class HistoryService {
    static let shared = HistoryService()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.englishagent.history", qos: .utility)

    private let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

    private var historyDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("EnglishAgent/history", isDirectory: true)
    }

    private let markdownDirectory = URL(fileURLWithPath: "/Users/lucasweiss/Downloads/Life/06-personal/english/grammar")

    private init() {
        try? fileManager.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
    }

    func save(input: String, output: String, model: String) {
        let now = Date()
        let day = dayFormatter.string(from: now)
        let time = timeFormatter.string(from: now)
        let id = UUID()

        queue.async { [self] in
            saveJSON(input: input, output: output, model: model, day: day, now: now, id: id)
            saveMarkdown(input: input, output: output, day: day, time: time)
        }
    }

    // MARK: - JSON (for future LLM analysis)

    private func saveJSON(input: String, output: String, model: String, day: String, now: Date, id: UUID) {
        let entry = TranslationEntry(id: id, timestamp: now, inputText: input, translatedText: output, model: model)
        let dayFile = historyDirectory.appendingPathComponent("\(day).json")

        var entries = loadEntries(from: dayFile)
        entries.append(entry)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: dayFile, options: .atomic)
    }

    private func loadEntries(from url: URL) -> [TranslationEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TranslationEntry].self, from: data)) ?? []
    }

    // MARK: - Markdown (for manual review in Life system)

    private func saveMarkdown(input: String, output: String, day: String, time: String) {
        let file = markdownDirectory.appendingPathComponent("\(day)-translation-log.md")

        if !fileManager.fileExists(atPath: file.path) {
            let frontmatter = """
            ---
            date: \(day)
            type: reference
            project: personal/english
            tags: [translations, grammar, daily-log]
            status: active
            ---

            # Translation Log — \(day)

            """
            try? frontmatter.write(to: file, atomically: true, encoding: .utf8)
        }

        let entry = """

        ## \(time)

        **Original:** \(input)

        **Translation:** \(output)

        ---

        """

        guard let data = entry.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: file) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    }
}
