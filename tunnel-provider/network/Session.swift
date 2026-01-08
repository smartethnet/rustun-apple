import Foundation
import Network
import NetworkExtension

/// Session 管理单个连接的生命周期
class Session {
    private var socket: NWConnection
    private var closed = true
    private var closedLock = NSLock()
    
    private var inputStream: [UInt8] = []
    private var lastActiveTime: Date?
    private let timeoutInterval: TimeInterval = 30.0
    
    private let identity: String
    private let cryptoBlock: CryptoBlock
    private let keepaliveInterval: TimeInterval
    
    var onHandshakeReply: ((HandshakeReplyFrame) -> Void)?
    var onDataFrame: ((DataFrame) -> Void)?
    var onKeepAlive: ((KeepAliveFrame) -> Void)?
    var onClosed: (() -> Void)?
    
    init(socket: NWConnection, identity: String, cryptoBlock: CryptoBlock, keepaliveInterval: TimeInterval) {
        self.socket = socket
        self.identity = identity
        self.cryptoBlock = cryptoBlock
        self.keepaliveInterval = keepaliveInterval
    }
    
    func start(onReady: @escaping (Error?) -> Void) {
        socket.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                log(.debug, "RUSTUN_CLIENT: Connected to server")
                
                // Reset closed state when socket is ready
                self.closedLock.lock()
                self.closed = false
                self.closedLock.unlock()
                
                // Start read task
                DispatchQueue.global(qos: .background).async { [weak self] in
                    guard let self = self else { return }
                    log(.info, "start read task")
                    self.startReadTask()
                }
                
                // Perform handshake
                do {
                    try self.performHandshake()
                    self.lastActiveTime = Date()
                    onReady(nil)
                } catch {
                    log(.error, "handshake failed: \(error)")
                    self.close()
                    onReady(error)
                }
                
            case .failed(let error):
                log(.error, "RUSTUN_CLIENT: Connection failed with error: \(error)")
                self.close()
                onReady(error)
                
            case .cancelled:
                log(.error, "RUSTUN_CLIENT: Connection cancelled")
                self.close()
                onReady(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection cancelled"]))
                
            case .waiting(let error):
                log(.error, "RUSTUN_CLIENT: Connection waiting \(error)")
                self.socket.cancel()
                
            default:
                log(.debug, "RUSTUN_CLIENT: Connection state changed: \(state)")
            }
        }
        
        socket.start(queue: DispatchQueue.global(qos: .background))
    }
    
    private func performHandshake() throws {
        let handshakeFrame = Frame.handshake(HandshakeFrame(identity: identity))
        let frameData = try FrameParser.marshal(frame: handshakeFrame, cryptoBlock: cryptoBlock)
        write(frameData)
        log(.info, "Handshake payload sent")
    }
    
    private func startReadTask() {
        if isClosed() {
            return
        }
        
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
            
            self.input(data: receivedData)
            
            if isComplete {
                self.close()
            } else {
                self.startReadTask()
            }
        }
    }
    
    private func input(data: Data) {
        inputStream.append(contentsOf: data)
        
        while inputStream.count >= FrameHeader.headerLength {
            do {
                let (frame, consumed) = try FrameParser.unmarshal(data: inputStream, cryptoBlock: cryptoBlock)
                inputStream.removeFirst(consumed)
                
                lastActiveTime = Date()
                handleFrame(frame)
            } catch FrameParserError.tooShort {
                break
            } catch {
                log(.debug, "Error parsing frame: \(error)")
                close()
                return
            }
        }
    }
    
    private func handleFrame(_ frame: Frame) {
        log(.debug, "Received frame: \(frame)")
        switch frame {
        case .handshakeReply(let reply):
            onHandshakeReply?(reply)
            
            // Start keepalive task
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                self.startKeepaliveTask()
            }
            
            // Start timeout check task
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                self.startTimeoutCheckTask()
            }
            
            
        case .data(let dataFrame):
            onDataFrame?(dataFrame)
            
        case .keepAlive(let keepAlive):
            onKeepAlive?(keepAlive)
            
        default:
            break
        }
    }
    
    func write(_ data: Data) {
        if isClosed() {
            return
        }
        
        let group = DispatchGroup()
        group.enter()
        
        socket.send(content: data, completion: .contentProcessed { [weak self] error in
            defer { group.leave() }
            if let error = error {
                self?.close()
                log(.debug, "Error sending data: \(error)")
            } else {
                // Update last active time when data is sent successfully
                self?.lastActiveTime = Date()
            }
        })
        
        group.wait()
    }
    
    private func startKeepaliveTask() {
        defer { log(.info, "close keepalive task") }
        
        while !isClosed() {
            Thread.sleep(forTimeInterval: keepaliveInterval)
            
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
                write(frameData)
            } catch {
                log(.debug, "Error marshaling keepalive frame: \(error)")
                close()
                return
            }
        }
    }
    
    private func startTimeoutCheckTask() {
        defer { log(.info, "close timeout check task") }
        
        while !isClosed() {
            Thread.sleep(forTimeInterval: 5.0)
            if let lastActive = lastActiveTime {
                let elapsed = Date().timeIntervalSince(lastActive)
                if elapsed > timeoutInterval {
                    log(.error, "Session timeout (no activity for \(elapsed)s), closing session")
                    close()
                    break
                }
            } 
        }
    }
    
    func sendData(_ data: Data) throws {
        if isClosed() {
            throw NSError(domain: "Session", code: -2, userInfo: [NSLocalizedDescriptionKey: "Session is closed"])
        }
        
        let dataFrame = Frame.data(DataFrame(payload: data))
        let frameData = try FrameParser.marshal(frame: dataFrame, cryptoBlock: cryptoBlock)
        write(frameData)
    }
    
    func close() {
        closedLock.lock()
        defer { closedLock.unlock() }
        
        if closed {
            return
        }
        
        closed = true
        socket.forceCancel()
        
        // async close callback
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.onClosed?()
        }
        log(.info, "close connection")
    }
    
    func isClosed() -> Bool {
        closedLock.lock()
        defer { closedLock.unlock() }
        return closed
    }
}

