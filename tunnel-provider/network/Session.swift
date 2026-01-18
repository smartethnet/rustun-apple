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
    
    // P2P 信息，用于在 keepalive 中上报
    private var localIPv6: String = ""
    private var localPort: UInt16 = 0
    private var stunIP: String = ""
    private var stunPort: UInt16 = 0
    private var p2pInfoLock = NSLock()
    
    // IPv6 发现任务控制
    private var ipv6DiscoveryTask: DispatchWorkItem?
    private var ipv6DiscoveryTaskLock = NSLock()
    
    var onHandshakeReply: ((HandshakeReplyFrame) -> Void)?
    var onDataFrame: ((DataFrame) -> Void)?
    var onKeepAlive: ((KeepAliveFrame) -> Void)?
    var onClosed: (() -> Void)?
    
    init(socket: NWConnection, identity: String, cryptoBlock: CryptoBlock, keepaliveInterval: TimeInterval, p2pPort: UInt16 = 0) {
        self.socket = socket
        self.identity = identity
        self.cryptoBlock = cryptoBlock
        self.keepaliveInterval = keepaliveInterval
        self.localPort = p2pPort
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
                    
                    // 启动 IPv6 发现和更新任务（在后台执行，不阻塞）
                    self.startIPv6DiscoveryTask()
                    
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
            } 
        })
        
        group.wait()
    }
    
    private func startKeepaliveTask() {
        defer { log(.info, "close keepalive task") }
        
        while !isClosed() {
            Thread.sleep(forTimeInterval: keepaliveInterval)
            
            // 获取最新的 P2P 信息
            p2pInfoLock.lock()
            let currentIPv6 = self.localIPv6
            let currentPort = self.localPort
            let currentStunIP = self.stunIP
            let currentStunPort = self.stunPort
            p2pInfoLock.unlock()
            
            let keepaliveFrame = Frame.keepAlive(KeepAliveFrame(
                identity: identity,
                ipv6: currentIPv6,
                port: currentPort,
                stunIP: currentStunIP,
                stunPort: currentStunPort,
                peerDetails: []
            ))
            
            do {
                let frameData = try FrameParser.marshal(frame: keepaliveFrame, cryptoBlock: cryptoBlock)
                log(.debug, "[RustunClient] send keepalive (IPv6: \(currentIPv6), Port: \(currentPort))")
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
        
        // 停止 IPv6 发现任务
        stopIPv6DiscoveryTask()
        
        socket.forceCancel()
        
        // async close callback
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.onClosed?()
        }
        log(.info, "close connection")
    }
    
    // MARK: - IPv6 Discovery
    
    /// 启动 IPv6 发现和更新任务（在后台执行，不阻塞）
    private func startIPv6DiscoveryTask() {
        stopIPv6DiscoveryTask()  // 确保之前的任务已停止
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // 立即执行一次 IPv6 发现
            self.discoverIPv6()
            
            // 然后每 5 分钟更新一次
            let updateInterval: TimeInterval = 300  // 5 分钟
            
            while !self.isClosed() {
                // 等待 5 分钟
                Thread.sleep(forTimeInterval: updateInterval)
                
                // 执行 IPv6 发现
                self.discoverIPv6()
            }
            
            log(.info, "RUSTUN_CLIENT: IPv6 discovery task stopped")
        }
        
        ipv6DiscoveryTaskLock.lock()
        self.ipv6DiscoveryTask = workItem
        ipv6DiscoveryTaskLock.unlock()
        
        // 在后台队列执行
        DispatchQueue.global(qos: .background).async(execute: workItem)
        log(.info, "RUSTUN_CLIENT: Started IPv6 discovery task")
    }
    
    /// 停止 IPv6 发现任务
    private func stopIPv6DiscoveryTask() {
        ipv6DiscoveryTaskLock.lock()
        defer { ipv6DiscoveryTaskLock.unlock() }
        
        if let task = ipv6DiscoveryTask {
            task.cancel()
            ipv6DiscoveryTask = nil
            log(.info, "RUSTUN_CLIENT: Stopped IPv6 discovery task")
        }
    }
    
    /// 通过公网 API 获取 IPv6 地址
    private func discoverIPv6() {
        let apis = [
            "https://api64.ipify.org",
            "https://ifconfig.co/ip",
            "https://ipv6.icanhazip.com"
        ]
        
        for apiURL in apis {
            if let ipv6 = self.fetchIPv6FromURL(apiURL) {
                // 验证是否是有效的 IPv6 地址
                if self.isValidIPv6(ipv6) {
                    p2pInfoLock.lock()
                    if ipv6 != self.localIPv6 {
                        let oldIPv6 = self.localIPv6
                        self.localIPv6 = ipv6
                        p2pInfoLock.unlock()
                        log(.info, "RUSTUN_CLIENT: IPv6 address updated: \(oldIPv6.isEmpty ? "none" : oldIPv6) -> \(ipv6) via \(apiURL)")
                    } else {
                        p2pInfoLock.unlock()
                    }
                    return
                }
            }
        }
        
        log(.info, "RUSTUN_CLIENT: Failed to get IPv6 address from all APIs")
    }
    
    /// 从指定 URL 获取 IPv6 地址
    private func fetchIPv6FromURL(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                log(.debug, "RUSTUN_CLIENT: Failed to fetch IPv6 from \(urlString): \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  let ipv6String = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                log(.debug, "RUSTUN_CLIENT: Invalid response from \(urlString)")
                return
            }
            
            result = ipv6String
        }
        
        task.resume()
        
        // 等待最多 5 秒
        if semaphore.wait(timeout: .now() + 5.0) == .timedOut {
            task.cancel()
            log(.debug, "RUSTUN_CLIENT: Timeout fetching IPv6 from \(urlString)")
            return nil
        }
        
        return result
    }
    
    /// 验证字符串是否是有效的 IPv6 地址
    private func isValidIPv6(_ ipv6: String) -> Bool {
        // 基本格式检查：包含冒号
        guard ipv6.contains(":") else {
            return false
        }
        
        // 排除 IPv4 地址（如果 API 返回了 IPv4）
        if ipv6.contains(".") && !ipv6.contains(":") {
            return false
        }
        
        // 排除链路本地地址和回环地址
        if ipv6.hasPrefix("fe80:") || ipv6 == "::1" {
            return false
        }
        
        // 使用正则表达式进行更严格的验证
        let ipv6Pattern = "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^([0-9a-fA-F]{1,4}:)*::([0-9a-fA-F]{1,4}:)*[0-9a-fA-F]{1,4}$|^([0-9a-fA-F]{1,4}:)*::[0-9a-fA-F]{1,4}$|^::([0-9a-fA-F]{1,4}:)+[0-9a-fA-F]{1,4}$|^([0-9a-fA-F]{1,4}:)+::[0-9a-fA-F]{1,4}$"
        
        let regex = try? NSRegularExpression(pattern: ipv6Pattern)
        let range = NSRange(location: 0, length: ipv6.utf16.count)
        return regex?.firstMatch(in: ipv6, options: [], range: range) != nil
    }
    
    
    func isClosed() -> Bool {
        closedLock.lock()
        defer { closedLock.unlock() }
        return closed
    }
}

