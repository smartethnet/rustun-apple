import Foundation

enum FrameType: UInt8 {
    case handshake = 1
    case keepAlive = 2
    case data = 3
    case handshakeReply = 4
    case probeIPv6 = 6
    case probeHolePunch = 7
}

struct FrameHeader {
    static let magic: UInt32 = 0x91929394
    static let version: UInt8 = 0x01
    static let headerLength = 8
    
    let frameType: FrameType
    let payloadLength: UInt16
    
    func toBytes() -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.append(contentsOf: FrameHeader.magic.bigEndianBytes)
        bytes.append(FrameHeader.version)
        bytes.append(frameType.rawValue)
        bytes.append(contentsOf: payloadLength.bigEndianBytes)
        return bytes
    }
    
    static func parse(from data: Data) -> FrameHeader? {
        guard data.count >= headerLength else { return nil }
        
        let magic = UInt32(bigEndian: data.withUnsafeBytes { $0.load(as: UInt32.self) })
        guard magic == FrameHeader.magic else { return nil }
        
        let version = data[4]
        guard version == FrameHeader.version else { return nil }
        
        guard let frameType = FrameType(rawValue: data[5]) else { return nil }
        
        let payloadLength = UInt16(bigEndian: data.subdata(in: 6..<8).withUnsafeBytes { $0.load(as: UInt16.self) })
        
        return FrameHeader(frameType: frameType, payloadLength: payloadLength)
    }
}

enum Frame {
    case handshake(HandshakeFrame)
    case handshakeReply(HandshakeReplyFrame)
    case keepAlive(KeepAliveFrame)
    case data(DataFrame)
    case probeIPv6(ProbeIPv6Frame)
    case probeHolePunch(ProbeHolePunchFrame)
}

struct HandshakeFrame: Codable {
    let identity: String
}

struct HandshakeReplyFrame: Codable {
    let privateIP: String
    let mask: String
    let gateway: String
    let peerDetails: [PeerDetail]
    
    enum CodingKeys: String, CodingKey {
        case privateIP = "private_ip"
        case mask
        case gateway
        case peerDetails = "peer_details"
    }
}

struct PeerDetail: Codable {
    let identity: String
    let privateIP: String
    let ciders: [String]
    let ipv6: String
    let port: UInt16
    let stunIP: String
    let stunPort: UInt16
    let lastActive: UInt64
    let isP2P: Bool
    
    enum CodingKeys: String, CodingKey {
        case identity
        case privateIP = "private_ip"
        case ciders
        case ipv6
        case port
        case stunIP = "stun_ip"
        case stunPort = "stun_port"
        case lastActive = "last_active"
        case isP2P = "is_p2p"
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
        // Server doesn't send isP2P, it's calculated on client side, default to false
        isP2P = try container.decodeIfPresent(Bool.self, forKey: .isP2P) ?? false
    }
    
    init(identity: String, privateIP: String, ciders: [String], ipv6: String, port: UInt16, stunIP: String, stunPort: UInt16, lastActive: UInt64, isP2P: Bool) {
        self.identity = identity
        self.privateIP = privateIP
        self.ciders = ciders
        self.ipv6 = ipv6
        self.port = port
        self.stunIP = stunIP
        self.stunPort = stunPort
        self.lastActive = lastActive
        self.isP2P = isP2P
    }
}

struct KeepAliveFrame: Codable {
    let identity: String
    let ipv6: String
    let port: UInt16
    let stunIP: String
    let stunPort: UInt16
    let peerDetails: [PeerDetail]
    
    enum CodingKeys: String, CodingKey {
        case identity
        case ipv6
        case port
        case stunIP = "stun_ip"
        case stunPort = "stun_port"
        case peerDetails = "peer_details"
    }
}

struct ProbeIPv6Frame: Codable {
    let identity: String
}

struct ProbeHolePunchFrame: Codable {
    let identity: String
}

struct DataFrame {
    let payload: Data
}

extension UInt32 {
    var bigEndianBytes: [UInt8] {
        var value = self.bigEndian
        return withUnsafeBytes(of: &value) { Array($0) }
    }
}

extension UInt16 {
    var bigEndianBytes: [UInt8] {
        var value = self.bigEndian
        return withUnsafeBytes(of: &value) { Array($0) }
    }
}

