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

        // Keep one rotating backup of whatever was on disk before this write.
        // A bug in the code deciding WHAT to persist (not this store itself)
        // can still overwrite good data with bad — this makes that always
        // recoverable instead of only the specific cases already found.
        if FileManager.default.fileExists(atPath: url.path) {
            let backupURL = url.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: url, to: backupURL)
        }

        let data = try JSONEncoder.inceptLaunch.encode(value)
        try data.write(to: url, options: [.atomic])
    }
}
