import Foundation

/// VPN configuration model
struct VPNConfig: Codable, Identifiable {
    var id = UUID()
    var name: String
    var serverAddress: String
    var serverPort: Int
    var identity: String
    var cryptoType: CryptoType
    var cryptoKey: String
    var enableP2P: Bool
    var keepaliveInterval: Int
    
    enum CodingKeys: String, CodingKey {
        case name, serverAddress, serverPort, identity, cryptoType, cryptoKey, enableP2P, keepaliveInterval
    }
    
    init(id: UUID = UUID(),
         name: String = "Default",
         serverAddress: String = "",
         serverPort: Int = 8080,
         identity: String = "",
         cryptoType: CryptoType = .chacha20,
         cryptoKey: String = "",
         enableP2P: Bool = true,
         keepaliveInterval: Int = 10) {
        self.id = id
        self.name = name
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.identity = identity
        self.cryptoType = cryptoType
        self.cryptoKey = cryptoKey
        self.enableP2P = enableP2P
        self.keepaliveInterval = keepaliveInterval
    }
}

/// Encryption types supported by Rustun
enum CryptoType: String, Codable, CaseIterable {
    case chacha20 = "chacha20"
    case aes256 = "aes256"
    case xor = "xor"
    case plain = "plain"
    
    var displayName: String {
        switch self {
        case .chacha20: return "ChaCha20-Poly1305 (Recommended)"
        case .aes256: return "AES-256-GCM"
        case .xor: return "XOR (Testing Only)"
        case .plain: return "Plain (No Encryption)"
        }
    }
}

/// VPN status
enum VPNStatus: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case error = "Error"
    
    var iconName: String {
        switch self {
        case .disconnected: return "circle"
        case .connecting: return "circle.dotted"
        case .connected: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "blue"
        case .connected: return "green"
        case .error: return "red"
        }
    }
}

