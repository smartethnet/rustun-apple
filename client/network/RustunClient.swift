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
    private var socket: NWConnection?
    private let serverAddress: String
    private let serverPort: UInt16
    private let identity: String
    private let cryptoBlock: CryptoBlock
    private let keepaliveInterval: TimeInterval
    
    private var inputStream: [UInt8] = []
    
    private var stateLock = NSLock()
    private var state = TunnelState.stateInitialize
    
    private var closed = false
    private var closedLock = NSLock()
    
    private var lastActiveTime: Date?
    private let timeoutInterval: TimeInterval = 30.0
    
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
        
        self.socket = NWConnection(host: host, port: port, using: .tcp)
        
        self.socket?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                log(.debug, "RUSTUN_CLIENT: Connected to server \(self.serverAddress):\(self.serverPort)")
                guard let socket = self.socket else {
                    self.reconnect(onReady)
                    return
                }
                
                DispatchQueue.global(qos: .background).async { [weak self] in
                    guard let self = self else { return }
                    log(.info, "start read task")
                    self.startReadTask()
                }
                
                DispatchQueue.global(qos: .background).async { [weak self] in
                    guard let self = self else { return }
                    self.startKeepaliveTask()
                }
                
                do {
                    try self.performHandshake()
                    self.setState(.stateConnected)
                    self.lastActiveTime = Date()
                    onReady(nil)
                } catch {
                    log(.error, "handshake failed: \(error)")
                    self.reconnect(onReady)
                }
                
            case .failed(let error):
                log(.error, "RUSTUN_CLIENT: Connection failed with error: \(error) \(self.serverAddress):\(self.serverPort) \(self.getState())")
                if self.getState() == .stateInitialize {
                    self.reconnect(onReady)
                }
                
            case .cancelled:
                log(.error, "RUSTUN_CLIENT: Connection cancelled \(self.serverAddress):\(self.serverPort)")
                self.reconnect(onReady)
                
            case .waiting(let error):
                log(.error, "RUSTUN_CLIENT: Connection waiting \(self.serverAddress) \(self.serverPort) \(error) \(self.getState())")
                self.setState(.stateConnecting)
                self.socket?.cancel()
                
            default:
                log(.debug, "RUSTUN_CLIENT: Connection state changed: \(state) \(self.serverAddress):\(self.serverPort)")
            }
        }
        
        self.socket?.start(queue: DispatchQueue.global(qos: .background))
    }
    
    private func reconnect(_ onReady: @escaping (Error?) -> Void) {
        self.stateLock.lock()
        if self.state == .stateReconnect {
            self.stateLock.unlock()
            return
        }
        self.state = .stateReconnect
        self.stateLock.unlock()
        
        self.close()
        
        sleep(3)
        self.run(onReady: onReady)
    }
    
    private func performHandshake() throws {
        let handshakeFrame = Frame.handshake(HandshakeFrame(identity: identity))
        let frameData = try FrameParser.marshal(frame: handshakeFrame, cryptoBlock: cryptoBlock)
        self.write(frameData)
        log(.info, "Handshake payload sent")
    }
    
    private func startReadTask() {
        if self.isClosed() {
            return
        }
        
        guard let socket = self.socket else { return }
        
        socket.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }
            
            if let error = error {
                log(.debug, "Error while receiving data: \(error)")
                self.close()
                return
            }
            
            if !isComplete {
                log(.debug, "NOT complete")
            }
            
            guard let receivedData = data, receivedData.count > 0 else {
                return
            }
            
            log(.debug, "Received data: \(receivedData.count) bytes")
            self.input(data: receivedData)
            
            if isComplete {
                self.close()
            } else {
                self.startReadTask()
            }
        }
    }
    
    // 处理接收到的数据，解析帧
    private func input(data: Data) {
        self.inputStream.append(contentsOf: data)
        
        while inputStream.count >= FrameHeader.headerLength {
            do {
                let (frame, consumed) = try FrameParser.unmarshal(data: inputStream, cryptoBlock: cryptoBlock)
                inputStream.removeFirst(consumed)
                
                self.lastActiveTime = Date()
                self.handleFrame(frame)
            } catch FrameParserError.tooShort {
                break
            } catch {
                log(.debug, "Error parsing frame: \(error)")
                self.close()
                return
            }
        }
    }
    
    private func handleFrame(_ frame: Frame) {
        log(.debug, "Received frame: \(frame)")
        switch frame {
        case .handshakeReply(let reply):
            onHandshakeReply?(reply)
            
        case .data(let dataFrame):
            onDataFrame?(dataFrame)
            
        case .keepAlive(let keepAlive):
            onKeepAlive?(keepAlive)
            
        default:
            break
        }
    }
    
    // Write task - 发送数据
    func write(_ data: Data) {
        if self.isClosed() {
            return
        }
        
        guard let socket = self.socket else { return }
        
        let group = DispatchGroup()
        group.enter()
        
        socket.send(content: data, completion: .contentProcessed { [weak self] error in
            defer { group.leave() }
            if let error = error {
                self?.close()
                log(.debug, "Error sending data: \(error)")
            }
        })
        
        group.wait()
    }
    
    // Keepalive task - 定时发送 keepalive
    private func startKeepaliveTask() {
        defer { log(.info, "close keepalive task") }
        
        while !self.isClosed() {
            let keepaliveFrame = Frame.keepAlive(KeepAliveFrame(
                identity: identity,
                ipv6: "",
                port: 0,
                stunIP: "",
                stunPort: 0,
                peerDetails: []
            ))
            
            do {
                let frameData = try FrameParser.marshal(frame: keepaliveFrame, cryptoBlock: cryptoBlock)
                log(.debug, "[RustunClient] send keepalive")
                self.write(frameData)
            } catch {
                log(.debug, "Error marshaling keepalive frame: \(error)")
                self.close()
                return
            }
            
            Thread.sleep(forTimeInterval: self.keepaliveInterval)
        }
    }
    
    func sendData(_ data: Data) throws {
        if getState() != .stateConnected {
            log(.debug, "session state \(getState())")
            throw NSError(domain: "RustunClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Not connected"])
        }
        
        let dataFrame = Frame.data(DataFrame(payload: data))
        let frameData = try FrameParser.marshal(frame: dataFrame, cryptoBlock: cryptoBlock)
        self.write(frameData)
    }
    
    func close() {
        closedLock.lock()
        defer { closedLock.unlock() }
        
        if closed {
            return
        }
        
        closed = true
        socket?.forceCancel()
        socket = nil
        onDisconnected?()
        log(.info, "close connection")
    }
    
    func isClosed() -> Bool {
        closedLock.lock()
        defer { closedLock.unlock() }
        return closed
    }
    
    private func setState(_ newState: TunnelState) {
        stateLock.lock()
        defer { stateLock.unlock() }
        state = newState
    }
    
    private func getState() -> TunnelState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state
    }
}
