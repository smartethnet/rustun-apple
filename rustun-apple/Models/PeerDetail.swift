import Foundation

struct PeerDetail: Codable, Identifiable {
    let id: String
    let identity: String
    let privateIP: String
    let ciders: [String]
    let ipv6: String
    let port: UInt16
    let stunIP: String
    let stunPort: UInt16
    let lastActive: UInt64
    
    enum CodingKeys: String, CodingKey {
        case identity
        case privateIP = "private_ip"
        case ciders
        case ipv6
        case port
        case stunIP = "stun_ip"
        case stunPort = "stun_port"
        case lastActive = "last_active"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identity = try container.decode(String.self, forKey: .identity)
        privateIP = try container.decode(String.self, forKey: .privateIP)
        ciders = try container.decode([String].self, forKey: .ciders)
        ipv6 = try container.decode(String.self, forKey: .ipv6)
        port = try container.decode(UInt16.self, forKey: .port)
        stunIP = try container.decode(String.self, forKey: .stunIP)
        stunPort = try container.decode(UInt16.self, forKey: .stunPort)
        lastActive = try container.decode(UInt64.self, forKey: .lastActive)
        // Use identity as id for Identifiable
        id = identity
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identity, forKey: .identity)
        try container.encode(privateIP, forKey: .privateIP)
        try container.encode(ciders, forKey: .ciders)
        try container.encode(ipv6, forKey: .ipv6)
        try container.encode(port, forKey: .port)
        try container.encode(stunIP, forKey: .stunIP)
        try container.encode(stunPort, forKey: .stunPort)
        try container.encode(lastActive, forKey: .lastActive)
    }
}

