import Foundation
import NetworkExtension
import Darwin

struct PeerMeta {
    let identity: String
    let privateIP: String
    let ciders: [String]
    var ipv6: String
    var port: UInt16
    var stunIP: String
    var stunPort: UInt16
    var lastActive: Date?
    var remoteAddr: String?
}

class P2PService {
    private var socketFD: Int32 = -1
    private var receiveSource: DispatchSourceRead?
    private var isRunning = false
    private var localPort: UInt16 = 0
    
    // peer list
    private var peers: [String: PeerMeta] = [:]
    private var peersLock = NSLock()
    
    private let probeInterval: TimeInterval = 10.0
    private let activeThreshold: TimeInterval = 15.0
    
    private var identity: String = ""
    private var cryptoBlock: CryptoBlock?
    
    // Callback for handling received DataFrame from P2P
    var onDataFrameReceived: ((DataFrame) -> Void)?
    
    init(identity: String, cryptoBlock: CryptoBlock) {
        self.identity = identity
        self.cryptoBlock = cryptoBlock
    }
    
    func startListening(on port: UInt16, completion: @escaping (Error?) -> Void) {
        if isRunning {
            completion(NSError(domain: "P2PService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service is already running"]))
            return
        }
        
        // Create IPv6 UDP socket, similar to golang's listenUDP
        let sock = socket(AF_INET6, SOCK_DGRAM, 0)
        if sock < 0 {
            let error = NSError(domain: "P2PService", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to create socket: \(String(cString: strerror(errno)))"])
            log(.error, "P2P Service: Failed to create socket: \(String(cString: strerror(errno)))")
            completion(error)
            return
        }
        
        // Set socket options
        var reuseAddr: Int32 = 1
        if setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size)) < 0 {
            let error = NSError(domain: "P2PService", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to set SO_REUSEADDR: \(String(cString: strerror(errno)))"])
            log(.error, "P2P Service: Failed to set SO_REUSEADDR: \(String(cString: strerror(errno)))")
            close(sock)
            completion(error)
            return
        }
        
        // Bind to IPv6 address [::]:port
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_port = port.bigEndian
        addr.sin6_addr = in6addr_any
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }
        
        if bindResult < 0 {
            let error = NSError(domain: "P2PService", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to bind socket: \(String(cString: strerror(errno)))"])
            log(.error, "P2P Service: Failed to bind socket: \(String(cString: strerror(errno)))")
            close(sock)
            completion(error)
            return
        }
        
        // Set socket to non-blocking mode
        var flags = fcntl(sock, F_GETFL, 0)
        if flags < 0 {
            let error = NSError(domain: "P2PService", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to get socket flags: \(String(cString: strerror(errno)))"])
            log(.error, "P2P Service: Failed to get socket flags: \(String(cString: strerror(errno)))")
            close(sock)
            completion(error)
            return
        }
        
        if fcntl(sock, F_SETFL, flags | O_NONBLOCK) < 0 {
            let error = NSError(domain: "P2PService", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to set non-blocking mode: \(String(cString: strerror(errno)))"])
            log(.error, "P2P Service: Failed to set non-blocking mode: \(String(cString: strerror(errno)))")
            close(sock)
            completion(error)
            return
        }
        
        self.socketFD = sock
        self.localPort = port
        self.isRunning = true
        
        log(.info, "P2P Service: UDP socket listening on port \(port)")
        
        // Start receiving loop using DispatchSource
        startReceivingUDP()
        startProbeTimer()
        
        completion(nil)
    }
    
    private func startProbeTimer() {
        log(.info, "P2P Service: Started probe task (interval: \(probeInterval)s)")
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            while self.isActive() {
                // Send probes and wait for completion
                self.sendProbesToAllPeers()
                
                // Wait for next interval before next round
                Thread.sleep(forTimeInterval: self.probeInterval)
            }
            
            log(.info, "P2P Service: Probe task stopped")
        }
    }
    
    private func sendProbesToAllPeers() {
        peersLock.lock()
        let currentPeers = Array(peers.values)
        peersLock.unlock()
        
        guard let cryptoBlock = cryptoBlock else {
            log(.error, "P2P Service: Cannot send probes, cryptoBlock not set")
            return
        }
        
        // Use DispatchGroup to wait for all async sends to complete
        let group = DispatchGroup()
        
        for peer in currentPeers {
            guard !peer.ipv6.isEmpty else {
                continue
            }
            
            log(.info, "P2P Service: probe ipv6 to peer [\(peer.ipv6)]:\(peer.port)")
            
            let probeFrame = Frame.probeIPv6(ProbeIPv6Frame(identity: identity))
            
            do {
                let frameData = try FrameParser.marshal(frame: probeFrame, cryptoBlock: cryptoBlock)
                
                group.enter()
                sendData(frameData, to: peer.ipv6, port: peer.port) { error in
                    if let error = error {
                        log(.debug, "P2P Service: Failed to send probe to \(peer.identity): \(error.localizedDescription)")
                    } else {
                        log(.debug, "P2P Service: Sent probeIPv6 to \(peer.identity) at \(peer.ipv6):\(peer.port)")
                    }
                    group.leave()
                }
            } catch {
                log(.error, "P2P Service: Failed to marshal probeIPv6 frame: \(error.localizedDescription)")
            }
        }
        
        // Wait for all sends to complete (with timeout to avoid hanging forever)
        _ = group.wait(timeout: .now() + 30.0)
    }
    
    private func startReceivingUDP() {
        guard isActive() && socketFD >= 0 else {
            return
        }
        
        let queue = DispatchQueue.global(qos: .background)
        let source = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: queue)
        
        source.setEventHandler { [weak self] in
            guard let self = self, self.isActive() else {
                return
            }
            
            // Read all available packets in a loop
            while self.isActive() {
                var buffer = [UInt8](repeating: 0, count: 2048)
                var addr = sockaddr_in6()
                var addrLen = socklen_t(MemoryLayout<sockaddr_in6>.size)
                
                let bytesRead = withUnsafeMutablePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                        recvfrom(self.socketFD, &buffer, buffer.count, 0, sockAddrPtr, &addrLen)
                    }
                }
                
                if bytesRead < 0 {
                    let err = errno
                    if err == EAGAIN || err == EWOULDBLOCK {
                        // No more data available, exit loop
                        break
                    }
                    log(.error, "P2P Service: Error receiving UDP data: \(String(cString: strerror(err)))")
                    break
                }
                
                if bytesRead == 0 {
                    break
                }
                
                // Extract source IP and port
                let sourcePort = UInt16(bigEndian: addr.sin6_port)
                let sourceIP = self.formatIPv6Address(addr.sin6_addr)
                
                log(.debug, "P2P Service: Received \(bytesRead) bytes from \(sourceIP):\(sourcePort)")
                
                if let cryptoBlock = self.cryptoBlock {
                    do {
                        // Use buffer slice directly
                        let (frame, _) = try FrameParser.unmarshal(data: Array(buffer[..<Int(bytesRead)]), cryptoBlock: cryptoBlock)
                        
                        switch frame {
                        case .probeIPv6(let probe):
                            log(.info, "P2P Service: Received probeIPv6 from \(probe.identity) at \(sourceIP):\(sourcePort)")
                            self.handleProbeIPv6(from: probe.identity, sourceIP: sourceIP, sourcePort: sourcePort)
                            continue
                            
                        case .data(let dataFrame):
                            log(.debug, "P2P Service: Received DataFrame (\(dataFrame.payload.count) bytes) from \(sourceIP):\(sourcePort)")
                            // Notify callback about received DataFrame
                            self.onDataFrameReceived?(dataFrame)
                            continue
                            
                        default:
                            log(.debug, "P2P Service: Received unhandled frame type from \(sourceIP):\(sourcePort)")
                            continue
                        }
                    } catch {
                        log(.debug, "P2P Service: Failed to parse frame, treating as raw data: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        source.setCancelHandler { [weak self] in
            log(.debug, "P2P Service: Receive source cancelled")
        }
        
        source.resume()
        self.receiveSource = source
    }
    
    private func formatIPv6Address(_ addr: in6_addr) -> String {
        let bytes = withUnsafeBytes(of: addr.__u6_addr) { Array($0) }
        return String(format: "%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x",
                     bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                     bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
    }
    
    private func parseIPv6Address(_ ipString: String) -> in6_addr? {
        var addr = in6_addr()
        // Use inet_pton to parse IPv6 address (standard POSIX function)
        let result = ipString.withCString { cString in
            inet_pton(AF_INET6, cString, &addr)
        }
        
        // inet_pton returns 1 on success, 0 on invalid address, -1 on error
        guard result == 1 else {
            return nil
        }
        
        return addr
    }
    
    private func handleProbeIPv6(from identity: String, sourceIP: String, sourcePort: UInt16) {
        peersLock.lock()
        defer { peersLock.unlock() }
        
        if var peer = peers[identity] {
            peer.lastActive = Date()
            peer.remoteAddr = "\(sourceIP):\(sourcePort)"
            peers[identity] = peer
            log(.debug, "P2P Service: Updated peer \(identity) lastActive and remoteAddr")
        } else {
            log(.info, "P2P Service: Received probeIPv6 from unknown peer: \(identity)")
        }
    }
    
    func sendData(_ data: Data, to host: String, port: UInt16, completion: ((Error?) -> Void)? = nil) {
        guard socketFD >= 0 && isActive() else {
            let error = NSError(domain: "P2PService", code: -3, userInfo: [NSLocalizedDescriptionKey: "UDP socket not initialized"])
            log(.error, "P2P Service: UDP socket not initialized")
            completion?(error)
            return
        }
        
        // Normalize IPv6 address format: ensure it has brackets for display/logging
        var ipString = host.trimmingCharacters(in: .whitespaces)
        var displayHost = host
        
        // Remove brackets if present for parsing
        if ipString.hasPrefix("[") && ipString.hasSuffix("]") {
            ipString = String(ipString.dropFirst().dropLast())
        } else {
            // If no brackets, add them for display (IPv6 addresses should have brackets)
            displayHost = "[\(ipString)]"
        }
        
        guard let addr = parseIPv6Address(ipString) else {
            let error = NSError(domain: "P2PService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid IPv6 address: \(host)"])
            log(.error, "P2P Service: Invalid IPv6 address: \(host)")
            completion?(error)
            return
        }
        
        // Use sendto() to send data to remote address, similar to golang's conn.WriteToUDP(data, remoteAddr)
        var remoteAddr = sockaddr_in6()
        remoteAddr.sin6_family = sa_family_t(AF_INET6)
        remoteAddr.sin6_port = port.bigEndian
        remoteAddr.sin6_addr = addr
        
        // Convert Data to [UInt8] and use withUnsafeBufferPointer
        let bytes = Array(data)
        let result = bytes.withUnsafeBufferPointer { buffer in
            withUnsafePointer(to: &remoteAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                    sendto(socketFD, buffer.baseAddress, bytes.count, 0, sockAddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
                }
            }
        }
        
        if result < 0 {
            let err = errno
            let error = NSError(domain: "P2PService", code: Int(err), userInfo: [NSLocalizedDescriptionKey: "Failed to send data: \(String(cString: strerror(err)))"])
            log(.error, "P2P Service: Error sending data to \(displayHost):\(port): \(String(cString: strerror(err)))")
            completion?(error)
        } else {
            log(.debug, "P2P Service: Sent \(data.count) bytes to \(displayHost):\(port)")
            completion?(nil)
        }
    }
    
    func rewritePeers(_ peerDetails: [PeerDetail]) {
        peersLock.lock()
        defer { peersLock.unlock() }
        
        peers.removeAll()
        
        for detail in peerDetails {
            let peer = PeerMeta(
                identity: detail.identity,
                privateIP: detail.privateIP,
                ciders: detail.ciders,
                ipv6: detail.ipv6,
                port: detail.port,
                stunIP: detail.stunIP,
                stunPort: detail.stunPort,
                lastActive: nil,
                remoteAddr: nil
            )
            peers[detail.identity] = peer
        }
        
        log(.info, "P2P Service: Rewrote \(peerDetails.count) peers")
    }
    
    func insertOrUpdatePeers(_ peerDetails: [PeerDetail]) {
        peersLock.lock()
        defer { peersLock.unlock() }
        
        for detail in peerDetails {
            if var existingPeer = peers[detail.identity] {
                if !detail.ipv6.isEmpty && existingPeer.ipv6 != detail.ipv6 {
                    existingPeer.ipv6 = detail.ipv6
                    existingPeer.lastActive = nil
                    existingPeer.remoteAddr = nil
                }
                if !detail.stunIP.isEmpty && existingPeer.stunIP != detail.stunIP {
                    existingPeer.stunIP = detail.stunIP
                    existingPeer.stunPort = detail.stunPort
                }
                peers[detail.identity] = existingPeer
            } else {
                let peer = PeerMeta(
                    identity: detail.identity,
                    privateIP: detail.privateIP,
                    ciders: detail.ciders,
                    ipv6: detail.ipv6,
                    port: detail.port,
                    stunIP: detail.stunIP,
                    stunPort: detail.stunPort,
                    lastActive: nil,
                    remoteAddr: nil
                )
                peers[detail.identity] = peer
            }
        }
        
        log(.info, "P2P Service: Inserted/updated \(peerDetails.count) peers")
    }
    
    func isPeerActive(_ identity: String) -> Bool {
        peersLock.lock()
        defer { peersLock.unlock() }
        
        guard let peer = peers[identity] else {
            return false
        }
        
        guard let lastActive = peer.lastActive else {
            return false
        }
        
        let elapsed = Date().timeIntervalSince(lastActive)
        return elapsed <= activeThreshold
    }
    
    /// Get lastActive timestamp for a peer
    /// Returns nil if peer doesn't exist or has no lastActive timestamp
    func getPeerLastActive(_ identity: String) -> UInt64? {
        peersLock.lock()
        defer { peersLock.unlock() }
        
        guard let peer = peers[identity],
              let lastActive = peer.lastActive else {
            return nil
        }
        
        // Convert Date to Unix timestamp (seconds since 1970)
        return UInt64(lastActive.timeIntervalSince1970)
    }
    
    /// Get lastActive timestamps for all peers
    /// Returns a dictionary mapping peer identity to lastActive timestamp
    func getAllPeersLastActive() -> [String: UInt64] {
        peersLock.lock()
        defer { peersLock.unlock() }
        
        var result: [String: UInt64] = [:]
        for (identity, peer) in peers {
            if let lastActive = peer.lastActive {
                result[identity] = UInt64(lastActive.timeIntervalSince1970)
            }
        }
        return result
    }
    
    /// Find peer by destination IP address
    /// Checks if destination IP matches peer's private IP or falls within any CIDR range
    func findPeerByDestinationIP(_ destIP: String) -> PeerMeta? {
        peersLock.lock()
        defer { peersLock.unlock() }
        
        // Parse destination IP
        let components = destIP.split(separator: ".")
        guard components.count == 4,
              let ip0 = UInt8(components[0]),
              let ip1 = UInt8(components[1]),
              let ip2 = UInt8(components[2]),
              let ip3 = UInt8(components[3]) else {
            return nil
        }
        
        let destIPValue = (UInt32(ip0) << 24) | (UInt32(ip1) << 16) | (UInt32(ip2) << 8) | UInt32(ip3)
        
        for peer in peers.values {
            // Check exact match with peer's private IP
            if peer.privateIP == destIP {
                return peer
            }
            
            // Check if destination falls within peer's CIDR ranges
            for cidr in peer.ciders {
                if let (networkIP, prefixLength) = parseCIDR(cidr) {
                    let mask = (0xFFFFFFFF as UInt32) << (32 - prefixLength)
                    if (destIPValue & mask) == (networkIP & mask) {
                        return peer
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Parse CIDR notation (e.g., "192.168.1.0/24")
    private func parseCIDR(_ cidr: String) -> (networkIP: UInt32, prefixLength: Int)? {
        let components = cidr.split(separator: "/")
        guard components.count == 2,
              let prefixLength = Int(components[1]),
              prefixLength >= 0 && prefixLength <= 32 else {
            return nil
        }
        
        let ipComponents = components[0].split(separator: ".")
        guard ipComponents.count == 4,
              let ip0 = UInt8(ipComponents[0]),
              let ip1 = UInt8(ipComponents[1]),
              let ip2 = UInt8(ipComponents[2]),
              let ip3 = UInt8(ipComponents[3]) else {
            return nil
        }
        
        let networkIP = (UInt32(ip0) << 24) | (UInt32(ip1) << 16) | (UInt32(ip2) << 8) | UInt32(ip3)
        return (networkIP, prefixLength)
    }
    
    /// Send packet data via P2P to a peer
    /// Returns true if sent successfully, false otherwise
    func sendPacket(_ packetData: Data, to peer: PeerMeta) -> Bool {
        // Check if peer is active (has received data recently)
        guard let lastActive = peer.lastActive else {
            log(.debug, "P2P Service: Peer \(peer.identity) has no lastActive, skipping P2P")
            return false
        }
        
        let elapsed = Date().timeIntervalSince(lastActive)
        guard elapsed <= activeThreshold else {
            log(.debug, "P2P Service: Peer \(peer.identity) lastActive too old (\(elapsed)s), skipping P2P")
            return false
        }
        
        // Check if peer has IPv6 address and port
        guard !peer.ipv6.isEmpty && peer.port > 0 else {
            log(.debug, "P2P Service: Peer \(peer.identity) has no IPv6 address or port, skipping P2P")
            return false
        }
        
        // Encrypt and wrap packet in DataFrame
        guard let cryptoBlock = cryptoBlock else {
            log(.error, "P2P Service: No cryptoBlock available")
            return false
        }
        
        do {
            // Create DataFrame
            let dataFrame = Frame.data(DataFrame(payload: packetData))
            
            // Marshal and encrypt the frame
            let frameData = try FrameParser.marshal(frame: dataFrame, cryptoBlock: cryptoBlock)
            
            // Send via UDP (sendData will handle IPv6 address formatting)
            var sendSuccess = false
            sendData(frameData, to: peer.ipv6, port: peer.port) { error in
                if error == nil {
                    sendSuccess = true
                    log(.debug, "P2P Service: Successfully sent packet to peer \(peer.identity) via P2P")
                } else {
                    log(.debug, "P2P Service: Failed to send packet to peer \(peer.identity) via P2P: \(error?.localizedDescription ?? "unknown error")")
                }
            }
            
            return sendSuccess
        } catch {
            log(.error, "P2P Service: Failed to marshal packet frame: \(error.localizedDescription)")
            return false
        }
    }
    
    func stop() {
        if !isRunning {
            return
        }
        
        log(.info, "P2P Service: Stopping UDP socket")
        
        isRunning = false
        
        receiveSource?.cancel()
        receiveSource = nil
        
        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
        
        log(.info, "P2P Service: Stopped")
    }
    
    func isActive() -> Bool {
        return isRunning
    }
}
