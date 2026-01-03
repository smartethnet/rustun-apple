import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case error = "ERROR"
}

func log(_ level: LogLevel, _ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    // 获取当前时间
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let currentDate = dateFormatter.string(from: Date())
    
    // 提取文件名
    let fileName = (file as NSString).lastPathComponent
    
    // 输出日志
    NSLog("\(currentDate) [\(level.rawValue)] \(fileName):\(line) \(function) - \(message)")
}

// MARK: - 一些辅助函数

func parseCIDR(cidr: String) -> (ip: String, mask: String)? {
    let parts = cidr.split(separator: "/")
    guard parts.count == 2, let prefixLength = Int(parts[1]), prefixLength >= 0, prefixLength <= 32 else {
        return nil
    }
    
    let ip = String(parts[0])
    let mask = prefixLengthToSubnetMask(prefixLength: prefixLength)
    return (ip, mask)
}

func prefixLengthToSubnetMask(prefixLength: Int) -> String {
    var mask = UInt32.max << (32 - prefixLength)
    var parts: [String] = []
    for _ in 0..<4 {
        parts.insert(String(mask & 0xFF), at: 0)
        mask >>= 8
    }
    return parts.joined(separator: ".")
}

/// 将 UInt32 IP 转换为字符串
func convertToIP(_ ip: UInt32) -> String {
    return String(format: "%d.%d.%d.%d",
                  (ip >> 24) & 0xFF,
                  (ip >> 16) & 0xFF,
                  (ip >> 8) & 0xFF,
                  ip & 0xFF)
}

struct Node: Codable, Identifiable, Hashable {
    let id: Int
    let createdAt: Int
    let updatedAt: Int
    let deletedAt: Int?
    let protocolType: String
    let ip: String
    let port: Int
    let cipher: String
    let edgeId: Int
    let name: String

    // JSON 键与属性不匹配时，需要使用 CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case protocolType = "protocol"
        case ip
        case port
        case cipher
        case edgeId = "edge_id"
        case name
    }
}
