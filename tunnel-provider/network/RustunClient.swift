import Foundation
import Network
import NetworkExtension

enum TunnelState {
    case stateInitialize
    case stateConnecting
    case stateConnected
    case stateReconnect
}

class RustunClient {
    private let serverAddress: String
    private let serverPort: UInt16
    private let identity: String
    private let cryptoBlock: CryptoBlock
    private let keepaliveInterval: TimeInterval
    
    private var session: Session?
    
    var onHandshakeReply: ((HandshakeReplyFrame) -> Void)?
    var onDataFrame: ((DataFrame) -> Void)?
    var onKeepAlive: ((KeepAliveFrame) -> Void)?
    var onDisconnected: (() -> Void)?
    
    init(serverAddress: String, serverPort: UInt16, identity: String, cryptoConfig: String, keepaliveInterval: TimeInterval = 10) {
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.identity = identity
        self.keepaliveInterval = keepaliveInterval
        
        let cryptoType = CryptoType.from(config: cryptoConfig)
        self.cryptoBlock = createCryptoBlock(from: cryptoType)
    }
    
    func run(onReady: @escaping (Error?) -> Void) {
        let host = NWEndpoint.Host(self.serverAddress)
        let port = NWEndpoint.Port(integerLiteral: self.serverPort)
        
        log(.debug, "RUSTUN_CLIENT: Connecting to \(serverAddress):\(serverPort)")
        
        let socket = NWConnection(host: host, port: port, using: .tcp)
        let session = Session(
            socket: socket,
            identity: identity,
            cryptoBlock: cryptoBlock,
            keepaliveInterval: keepaliveInterval
        )
        
        self.session = session
        
        // Setup session callbacks
        session.onHandshakeReply = { [weak self] reply in
            guard let self = self else { return }
            self.onHandshakeReply?(reply)
        }
        
        session.onDataFrame = { [weak self] dataFrame in
            guard let self = self else { return }
            self.onDataFrame?(dataFrame)
        }
        
        session.onKeepAlive = { [weak self] keepAlive in
            guard let self = self else { return }
            self.onKeepAlive?(keepAlive)
        }
        
        // session closed, this will trigger only once and trigger reconnect
        session.onClosed = { [weak self] in
            guard let self = self else { return }
            log(.error, "RUSTUN_CLIENT: Session closed, will attempt reconnect")
            self.handleSessionClosed(onReady: onReady)
        }
        
        // Start session
        session.start { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                log(.error, "RUSTUN_CLIENT: Session start failed: \(error)")
                self.reconnect(onReady: onReady)
                return
            }
            
            log(.info, "RUSTUN_CLIENT: Session started successfully")
            onReady(nil)
        }
    }
    
    private func handleSessionClosed(onReady: @escaping (Error?) -> Void) {
        onDisconnected?()
        reconnect(onReady: onReady)
    }
    
    private func reconnect(onReady: @escaping (Error?) -> Void) {
        log(.info, "RUSTUN_CLIENT: Reconnecting in 3 seconds...")
        sleep(3)
        run(onReady: onReady)
    }
    
    func sendData(_ data: Data) throws {
        guard let session = session, !session.isClosed() else {
            return
        }
        try
        session.sendData(data)
    }
    
    func close() {
        guard let session = session, !session.isClosed() else {
            return
        }
        session.close()
    }
}
