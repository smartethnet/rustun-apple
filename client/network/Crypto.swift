import Foundation
import CryptoKit

protocol CryptoBlock {
    func encrypt(_ data: inout Data) throws
    func decrypt(_ data: inout Data) throws
}

enum CryptoType {
    case chacha20(String)
    case aes256(String)
    case xor(String)
    case plain
    
    static func from(config: String) -> CryptoType {
        let parts = config.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return .plain }
        
        let type = String(parts[0]).lowercased()
        let key = String(parts[1])
        
        switch type {
        case "chacha20", "chacha20poly1305":
            return .chacha20(key)
        case "aes256", "aes256gcm":
            return .aes256(key)
        case "xor":
            return .xor(key)
        default:
            return .plain
        }
    }
}

class ChaCha20Poly1305Block: CryptoBlock {
    private let key: SymmetricKey
    
    init(keyString: String) {
        let keyData = SHA256.hash(data: keyString.data(using: .utf8)!)
        self.key = SymmetricKey(data: keyData)
    }
    
    func encrypt(_ data: inout Data) throws {
        let nonce = try ChaChaPoly.Nonce(data: generateNonce())
        let sealedBox = try ChaChaPoly.seal(data, using: key, nonce: nonce)
        data = sealedBox.combined
    }
    
    func decrypt(_ data: inout Data) throws {
        let sealedBox = try ChaChaPoly.SealedBox(combined: data)
        data = try ChaChaPoly.open(sealedBox, using: key)
    }
    
    private func generateNonce() -> Data {
        var nonce = Data(count: 12)
        _ = nonce.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 12, bytes.baseAddress!)
        }
        return nonce
    }
}

class Aes256GcmBlock: CryptoBlock {
    private let key: SymmetricKey
    
    init(keyString: String) {
        let keyData = SHA256.hash(data: keyString.data(using: .utf8)!)
        self.key = SymmetricKey(data: keyData)
    }
    
    func encrypt(_ data: inout Data) throws {
        let nonce = try AES.GCM.Nonce(data: generateNonce())
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        data = sealedBox.combined!
    }
    
    func decrypt(_ data: inout Data) throws {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        data = try AES.GCM.open(sealedBox, using: key)
    }
    
    private func generateNonce() -> Data {
        var nonce = Data(count: 12)
        _ = nonce.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 12, bytes.baseAddress!)
        }
        return nonce
    }
}

class XorBlock: CryptoBlock {
    private let key: [UInt8]
    
    init(keyString: String) {
        self.key = Array(keyString.utf8)
    }
    
    func encrypt(_ data: inout Data) throws {
        var bytes = Array(data)
        for i in 0..<bytes.count {
            bytes[i] ^= key[i % key.count]
        }
        data = Data(bytes)
    }
    
    func decrypt(_ data: inout Data) throws {
        try encrypt(&data)
    }
}

class PlainBlock: CryptoBlock {
    func encrypt(_ data: inout Data) throws {
    }
    
    func decrypt(_ data: inout Data) throws {
    }
}

func createCryptoBlock(from config: CryptoType) -> CryptoBlock {
    switch config {
    case .chacha20(let key):
        return ChaCha20Poly1305Block(keyString: key)
    case .aes256(let key):
        return Aes256GcmBlock(keyString: key)
    case .xor(let key):
        return XorBlock(keyString: key)
    case .plain:
        return PlainBlock()
    }
}

