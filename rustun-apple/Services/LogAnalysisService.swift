import Foundation

/// Service for analyzing logs and detecting anomalies
class LogAnalysisService {
    static let shared = LogAnalysisService()
    
    private init() {}
    
    /// Analyze logs and detect anomalies
    func analyzeLogs(_ logs: [String]) -> LogAnalysisResult {
        var result = LogAnalysisResult()
        
        // Error patterns
        let errorPatterns = [
            "❌", "Error", "Failed", "failed", "error", "ERROR",
            "Exception", "exception", "Fatal", "fatal",
            "Connection refused", "Connection timeout", "Connection reset",
            "Network unreachable", "Host unreachable", "No route to host"
        ]
        
        // Warning patterns
        let warningPatterns = [
            "⚠️", "Warning", "warning", "WARN", "warn",
            "Retry", "retry", "Timeout", "timeout"
        ]
        
        // Success patterns
        let successPatterns = [
            "✅", "Success", "success", "Connected", "connected",
            "Established", "established"
        ]
        
        // Analyze each log entry
        for (index, log) in logs.enumerated() {
            let lowercasedLog = log.lowercased()
            
            // Check for errors
            for pattern in errorPatterns {
                if log.contains(pattern) || lowercasedLog.contains(pattern.lowercased()) {
                    result.errors.append(LogEntry(
                        index: index,
                        message: log,
                        severity: .error,
                        timestamp: extractTimestamp(from: log)
                    ))
                    break
                }
            }
            
            // Check for warnings
            for pattern in warningPatterns {
                if log.contains(pattern) || lowercasedLog.contains(pattern.lowercased()) {
                    result.warnings.append(LogEntry(
                        index: index,
                        message: log,
                        severity: .warning,
                        timestamp: extractTimestamp(from: log)
                    ))
                    break
                }
            }
            
            // Check for connection issues
            if lowercasedLog.contains("connection") && (lowercasedLog.contains("fail") || lowercasedLog.contains("error") || lowercasedLog.contains("timeout")) {
                result.connectionIssues.append(LogEntry(
                    index: index,
                    message: log,
                    severity: .error,
                    timestamp: extractTimestamp(from: log)
                ))
            }
            
            // Check for authentication issues
            if lowercasedLog.contains("auth") || lowercasedLog.contains("unauthorized") || lowercasedLog.contains("forbidden") {
                result.authenticationIssues.append(LogEntry(
                    index: index,
                    message: log,
                    severity: .error,
                    timestamp: extractTimestamp(from: log)
                ))
            }
        }
        
        // Calculate statistics
        result.totalLogs = logs.count
        result.errorCount = result.errors.count
        result.warningCount = result.warnings.count
        result.hasAnomalies = !result.errors.isEmpty || !result.warnings.isEmpty || !result.connectionIssues.isEmpty
        
        // Determine overall health
        if result.errorCount > 5 {
            result.healthStatus = .critical
        } else if result.errorCount > 0 || result.warningCount > 10 {
            result.healthStatus = .warning
        } else if result.warningCount > 0 {
            result.healthStatus = .degraded
        } else {
            result.healthStatus = .healthy
        }
        
        // Get recent errors (last 10)
        result.recentErrors = Array(result.errors.suffix(10))
        result.recentWarnings = Array(result.warnings.suffix(10))
        
        return result
    }
    
    /// Extract timestamp from log entry
    private func extractTimestamp(from log: String) -> Date? {
        // Try to parse timestamp from log format: [HH:mm:ss] message
        let patterns = [
            "\\[(\\d{2}:\\d{2}:\\d{2})\\]",  // [HH:mm:ss]
            "(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})"  // YYYY-MM-DD HH:mm:ss
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: log, range: NSRange(log.startIndex..., in: log)),
               let range = Range(match.range(at: 1), in: log) {
                let timestampString = String(log[range])
                
                let formatter = DateFormatter()
                if timestampString.contains("-") {
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                } else {
                    formatter.dateFormat = "HH:mm:ss"
                }
                
                return formatter.date(from: timestampString)
            }
        }
        
        return nil
    }
}

// MARK: - Models

struct LogAnalysisResult {
    var errors: [LogEntry] = []
    var warnings: [LogEntry] = []
    var connectionIssues: [LogEntry] = []
    var authenticationIssues: [LogEntry] = []
    var recentErrors: [LogEntry] = []
    var recentWarnings: [LogEntry] = []
    var totalLogs: Int = 0
    var errorCount: Int = 0
    var warningCount: Int = 0
    var hasAnomalies: Bool = false
    var healthStatus: HealthStatus = .healthy
}

struct LogEntry {
    let index: Int
    let message: String
    let severity: LogSeverity
    let timestamp: Date?
}

enum LogSeverity {
    case error
    case warning
    case info
}

enum HealthStatus {
    case healthy
    case degraded
    case warning
    case critical
    
    var description: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .degraded:
            return "Degraded"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }
    
    var emoji: String {
        switch self {
        case .healthy:
            return "✅"
        case .degraded:
            return "⚠️"
        case .warning:
            return "🔶"
        case .critical:
            return "🔴"
        }
    }
}

