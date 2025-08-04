class Utility: NSObject {
    static let fileManager = FileManager.default

    static func basePath() -> String {
        let path = "\(NSTemporaryDirectory())video_compress_zero"
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
            } catch {
                // Handle error: could log or propagate if desired
            }
        }
        return path
    }

    static func stripFileExtension(_ fileName: String) -> String {
        var components = fileName.components(separatedBy: ".")
        if components.count > 1 {
            components.removeLast()
            return components.joined(separator: ".")
        } else {
            return fileName
        }
    }

    static func getFileName(_ path: String) -> String {
        return stripFileExtension((path as NSString).lastPathComponent)
    }

    static func getPathUrl(_ path: String) -> URL {
        return URL(fileURLWithPath: excludeFileProtocol(path))
    }

    static func excludeFileProtocol(_ path: String) -> String {
        return path.replacingOccurrences(of: "file://", with: "")
    }

    static func excludeEncoding(_ path: String) -> String {
        return path.removingPercentEncoding ?? path
    }

    static func keyValueToJson(_ keyAndValue: [String: Any?]) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: keyAndValue as NSDictionary, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
        } catch {
            // Handle error: could log or return "{}"
        }
        return "{}"
    }

    static func deleteFile(_ path: String, clear: Bool = false) {
        let url = getPathUrl(path)
        let actualPath = url.path
        if fileManager.fileExists(atPath: actualPath) {
            try? fileManager.removeItem(atPath: actualPath)
        }
        if clear {
            try? fileManager.removeItem(atPath: actualPath)
        }
    }
}

