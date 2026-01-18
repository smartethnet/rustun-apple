import Foundation
import NetworkExtension
import os.log
import Network

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case error = "ERROR"
}

private let logSubsystem = "com.beyondnetwork.rustun-apple.tunnel-provider"
private let logCategory = "PacketTunnelProvider"

private let logger = OSLog(subsystem: logSubsystem, category: logCategory)

func log(_ level: LogLevel, _ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    // 提取文件名
    let fileName = (file as NSString).lastPathComponent
    
    // 格式化日志消息
    let logMessage = "[\(level.rawValue)] \(fileName):\(line) \(function) - [RUSTUN_PROVIDER] \(message)"
    
    // 使用 os_log 输出到系统日志（可以在 Console.app 中查看）
    // 使用 %{public}s 来标记消息为公开，这样在 Console.app 中就不会显示为 <private>
    let osLogType: OSLogType = .error
//    switch level {
//    case .debug:
//        osLogType = .debug
//    case .info:
//        osLogType = .info
//    case .error:
//        osLogType = .error
//    }
    
    // 使用 os_log 而不是 NSLog，并使用 %{public}s 格式
    os_log("%{public}@", log: logger, type: osLogType, logMessage)
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

func maskToPrefix(_ mask: String) -> Int {
    let parts = mask.split(separator: ".")
    guard parts.count == 4,
          let m0 = UInt8(parts[0]),
          let m1 = UInt8(parts[1]),
          let m2 = UInt8(parts[2]),
          let m3 = UInt8(parts[3]) else {
        return 32
    }
    
    let maskValue = (UInt32(m0) << 24) | (UInt32(m1) << 16) | (UInt32(m2) << 8) | UInt32(m3)
    
    // Count 1s in mask to get prefix length
    var prefixLength = 0
    var m = maskValue
    while m != 0 {
        prefixLength += 1
        m &= (m - 1) // Clear the rightmost 1 bit
    }
    
    return prefixLength
}

func parseSubnetMask(_ mask: String) -> String {
    if mask.contains(".") {
        return mask
    }
    
    if let prefixLength = Int(mask), prefixLength >= 0 && prefixLength <= 32 {
        return prefixLengthToSubnetMask(prefixLength: prefixLength)
    }
    
    return prefixLengthToSubnetMask(prefixLength: 32)
}

func parseCIDRRoute(_ cidr: String) -> NEIPv4Route? {
    guard let (ip, mask) = parseCIDR(cidr: cidr) else {
        return nil
    }
    return NEIPv4Route(destinationAddress: ip, subnetMask: mask)
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
