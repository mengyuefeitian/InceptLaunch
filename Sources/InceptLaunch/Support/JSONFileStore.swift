import Foundation

extension JSONEncoder {
    static var inceptLaunch: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var inceptLaunch: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct JSONFileStore<Value: Codable> {
    let url: URL

    func load(default defaultValue: Value) throws -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return defaultValue
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.inceptLaunch.decode(Value.self, from: data)
    }

    func save(_ value: Value) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.inceptLaunch.encode(value)
        try data.write(to: url, options: [.atomic])
    }
}
