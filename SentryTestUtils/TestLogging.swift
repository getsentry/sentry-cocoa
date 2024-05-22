import Foundation

public struct TestLogger {
    static var df: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return dateFormatter
    }()
    
    public static func log(_ line: Int, _ message: String) {
        print("\(df.string(from: Date())) [Sentry] [TEST] [\((#file as NSString).lastPathComponent):\(line)]: \(message)")
    }
}
