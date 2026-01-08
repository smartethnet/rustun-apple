import Foundation

enum FrameParserError: Error {
    case tooShort
    case invalidMagic
    case invalidVersion
    case invalidFrameType
    case decryptionFailed
    case deserializationFailed
}

class FrameParser {
    static func marshal(frame: Frame, cryptoBlock: CryptoBlock) throws -> Data {
        let payload: Data
        let frameType: FrameType
        
        switch frame {
        case .handshake(let handshake):
            frameType = .handshake
            payload = try serializeAndEncrypt(handshake, cryptoBlock: cryptoBlock)
            
        case .handshakeReply(let reply):
            frameType = .handshakeReply
            payload = try serializeAndEncrypt(reply, cryptoBlock: cryptoBlock)
            
        case .keepAlive(let keepAlive):
            frameType = .keepAlive
            payload = try serializeAndEncrypt(keepAlive, cryptoBlock: cryptoBlock)
            
        case .data(let dataFrame):
            frameType = .data
            var payloadData = dataFrame.payload
            try cryptoBlock.encrypt(&payloadData)
            payload = payloadData
            
        case .probeIPv6(let probe):
            frameType = .probeIPv6
            payload = try serializeAndEncrypt(probe, cryptoBlock: cryptoBlock)
            
        case .probeHolePunch(let probe):
            frameType = .probeHolePunch
            payload = try serializeAndEncrypt(probe, cryptoBlock: cryptoBlock)
        }
        
        let header = FrameHeader(frameType: frameType, payloadLength: UInt16(payload.count))
        var frameData = Data(header.toBytes())
        frameData.append(payload)
        
        return frameData
    }
    
    static func unmarshal(data: [UInt8], cryptoBlock: CryptoBlock) throws -> (Frame, Int) {
        guard data.count >= FrameHeader.headerLength else {
            throw FrameParserError.tooShort
        }
        
        // 直接使用索引访问解析 header 字段
        let magic = (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16) | (UInt32(data[2]) << 8) | UInt32(data[3])
        guard magic == FrameHeader.magic else {
            throw FrameParserError.invalidMagic
        }
        
        let version = data[4]
        guard version == FrameHeader.version else {
            throw FrameParserError.invalidVersion
        }
        
        guard let frameType = FrameType(rawValue: data[5]) else {
            throw FrameParserError.invalidFrameType
        }
        
        let payloadLength = (UInt16(data[6]) << 8) | UInt16(data[7])
        
        let totalLength = FrameHeader.headerLength + Int(payloadLength)
        guard data.count >= totalLength else {
            throw FrameParserError.tooShort
        }
        var payload = Array(data[FrameHeader.headerLength..<totalLength])
        
        let frame: Frame
        
        switch frameType {
        case .handshake:
            let handshake: HandshakeFrame = try decryptAndDeserialize(&payload, cryptoBlock: cryptoBlock)
            frame = .handshake(handshake)
            
        case .handshakeReply:
            let reply: HandshakeReplyFrame = try decryptAndDeserialize(&payload, cryptoBlock: cryptoBlock)
            frame = .handshakeReply(reply)
            
        case .keepAlive:
            let keepAlive: KeepAliveFrame = try decryptAndDeserialize(&payload, cryptoBlock: cryptoBlock)
            frame = .keepAlive(keepAlive)
            
        case .data:
            var payloadData = Data(payload)
            try cryptoBlock.decrypt(&payloadData)
            frame = .data(DataFrame(payload: payloadData))
            
        case .probeIPv6:
            let probe: ProbeIPv6Frame = try decryptAndDeserialize(&payload, cryptoBlock: cryptoBlock)
            frame = .probeIPv6(probe)
            
        case .probeHolePunch:
            let probe: ProbeHolePunchFrame = try decryptAndDeserialize(&payload, cryptoBlock: cryptoBlock)
            frame = .probeHolePunch(probe)
        }
        
        return (frame, totalLength)
    }
    
    private static func serializeAndEncrypt<T: Codable>(_ value: T, cryptoBlock: CryptoBlock) throws -> Data {
        let encoder = JSONEncoder()
        var jsonData = try encoder.encode(value)
        try cryptoBlock.encrypt(&jsonData)
        return jsonData
    }
    
    private static func decryptAndDeserialize<T: Decodable>(_ data: inout [UInt8], cryptoBlock: CryptoBlock) throws -> T {
        var dataObj = Data(data)
        try cryptoBlock.decrypt(&dataObj)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: dataObj)
    }
}

