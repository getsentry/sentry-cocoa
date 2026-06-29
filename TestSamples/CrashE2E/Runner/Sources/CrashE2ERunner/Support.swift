import Foundation

struct CrashE2EFailure: Error, CustomStringConvertible {
    let message: String

    var description: String { message }
}

func fail(_ message: String) throws -> Never {
    throw CrashE2EFailure(message: message)
}

func log(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    print("[\(formatter.string(from: Date()))] \(message)")
    fflush(stdout)
}

func absoluteURL(_ path: String, relativeTo base: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> URL {
    let url: URL
    if path.hasPrefix("/") {
        url = URL(fileURLWithPath: path)
    } else {
        url = URL(fileURLWithPath: path, relativeTo: base)
    }
    return url.standardizedFileURL
}

extension URL {
    func appendingPath(_ path: String, isDirectory: Bool = false) -> URL {
        if #available(macOS 13.0, *) {
            return appending(path: path, directoryHint: isDirectory ? .isDirectory : .notDirectory)
        } else {
            return appendingPathComponent(path, isDirectory: isDirectory)
        }
    }
}

extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try removeItem(at: url)
    }

    func ensureDirectory(at url: URL) throws {
        try createDirectory(at: url, withIntermediateDirectories: true)
    }
}

func prettyJSON(_ object: Any) -> String {
    let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object, options: options),
          let string = String(data: data, encoding: .utf8) else {
        return String(describing: object)
    }
    return string
}
