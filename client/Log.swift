import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case error = "ERROR"
}

func log(_ level: LogLevel, _ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let fileName = (file as NSString).lastPathComponent
    let logMessage = "\(timestamp) [\(level.rawValue)] \(fileName):\(line) - \(message)"
    
    print(logMessage)
    
    if level == .error {
        fputs(logMessage + "\n", stderr)
    }
}

