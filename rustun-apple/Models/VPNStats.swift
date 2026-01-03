import Foundation

/// VPN statistics
struct VPNStats {
    var connectedTime: TimeInterval = 0
    var rxBytes: UInt64 = 0
    var txBytes: UInt64 = 0
    var rxPackets: UInt64 = 0
    var txPackets: UInt64 = 0
    var p2pConnections: Int = 0
    var relayConnections: Int = 0
    
    var formattedRxBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(rxBytes), countStyle: .binary)
    }
    
    var formattedTxBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(txBytes), countStyle: .binary)
    }
    
    var formattedConnectedTime: String {
        let hours = Int(connectedTime) / 3600
        let minutes = (Int(connectedTime) % 3600) / 60
        let seconds = Int(connectedTime) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

