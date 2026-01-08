import NetworkExtension
import Foundation
import Darwin

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var stats: [String: UInt64] = [
        "rxBytes": UInt64(0),
        "txBytes": UInt64(0),
        "rxPackets": UInt64(0),
        "txPackets": UInt64(0)
    ]
    private var isReadingPackets = false
    private var rustunClient: RustunClient?
    private var handshakeReply: HandshakeReplyFrame?
    private var currentPeers: [PeerDetail] = []
    private var currentCIDRs: Set<String> = [] // Track current CIDRs for route management
    
    // Network configuration from handshake (doesn't change after initial setup)
    private var tunnelGateway: String?
    private var tunnelPrivateIP: String?
    private var tunnelMask: String?
    
    override init() {
        super.init()
        log(.info, "Initializing tunnel provider")
    }
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        log(.info, "Starting tunnel...")
        
        // Get configuration from protocolConfiguration
        guard let protocolConfig = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = protocolConfig.providerConfiguration as? [String: Any] else {
            let error = NSError(domain: "PacketTunnelProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid protocol configuration"])
            log(.error, "Invalid protocol configuration")
            completionHandler(error)
            return
        }
        
        // Extract rustun configuration
        guard let serverAddress = providerConfig["serverAddress"] as? String,
              let serverPort = providerConfig["serverPort"] as? Int,
              let identity = providerConfig["identity"] as? String,
              let cryptoType = providerConfig["cryptoType"] as? String,
              let cryptoKey = providerConfig["cryptoKey"] as? String else {
            let error = NSError(domain: "PacketTunnelProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing required rustun configuration"])
            log(.error, "Missing required rustun configuration")
            completionHandler(error)
            return
        }
        
        let keepaliveInterval = providerConfig["keepaliveInterval"] as? Int ?? 10
        let cryptoConfig = "\(cryptoType):\(cryptoKey)"
        
        log(.info, "Connecting to rustun server: \(serverAddress):\(serverPort)")
        log(.info, "Identity: \(identity)")
        
        // Create rustun client
        let client = RustunClient(
            serverAddress: serverAddress,
            serverPort: UInt16(serverPort),
            identity: identity,
            cryptoConfig: cryptoConfig,
            keepaliveInterval: TimeInterval(keepaliveInterval)
        )
        
        // Setup callbacks
        var connectionCompletionHandler: ((Error?) -> Void)? = completionHandler
    
        
        client.onHandshakeReply = { [weak self] reply in
            guard let self = self else { return }
            self.handleHandshakeReply(reply)
        }
        
        client.onDataFrame = { [weak self] dataFrame in
            guard let self = self else { return }
            self.handleDataFrame(dataFrame)
        }
        
        client.onKeepAlive = { [weak self] keepAlive in
            guard let self = self else { return }
            self.handleKeepAlive(keepAlive)
        }
        
        self.rustunClient = client
        
        // Set temporary tunnel settings first (required by Network Extension)
        let tempSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: serverAddress)
        let tempIPv4Settings = NEIPv4Settings(addresses: ["127.0.0.100"], subnetMasks: ["255.255.255.0"])
        tempSettings.ipv4Settings = tempIPv4Settings
        tempSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        tempSettings.mtu = 1430
        
        setTunnelNetworkSettings(tempSettings) { [weak self] error in
            guard let self = self else {
                completionHandler(NSError(domain: "PacketTunnelProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                return
            }
            
            if let error = error {
                log(.error, "Failed to set temporary tunnel settings: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            
            // Connect to server
            client.run(onReady: { error in
                if let error = error {
                    log(.error, "Failed to connect: \(error.localizedDescription)")
                    completionHandler(error)
                }
            })
            // Handshake reply will update the tunnel settings and complete the connection
            // For now, we complete immediately and let handshake reply update settings
            completionHandler(nil)
        }
    }
    
    private func handleHandshakeReply(_ reply: HandshakeReplyFrame) {
        log(.info, "Received handshake reply: privateIP=\(reply.privateIP), gateway=\(reply.gateway)")
        self.handshakeReply = reply
        
        // Store network configuration (these don't change after handshake)
        self.tunnelGateway = reply.gateway
        self.tunnelPrivateIP = reply.privateIP
        self.tunnelMask = reply.mask
        
        self.currentPeers = reply.peerDetails
        
        // Extract and store initial CIDRs
        var initialCIDRs: Set<String> = []
        for peer in reply.peerDetails {
            initialCIDRs.formUnion(peer.ciders)
        }
        self.currentCIDRs = initialCIDRs
        log(.info, "Initial peers: \(reply.peerDetails.count) peers, CIDRs: \(initialCIDRs.count)")
        
        // Configure tunnel network settings based on handshake reply
        updateTunnelRoutes()
    }
    
    private func handleKeepAlive(_ keepAlive: KeepAliveFrame) {
        log(.debug, "Received keepalive: \(keepAlive.peerDetails.count) peers")
        
        // Extract new CIDRs from keepalive
        var newCIDRs: Set<String> = []
        for peer in keepAlive.peerDetails {
            newCIDRs.formUnion(peer.ciders)
        }
        
        // Compare with current CIDRs
        let addedCIDRs = newCIDRs.subtracting(currentCIDRs)
        let removedCIDRs = currentCIDRs.subtracting(newCIDRs)
        
        if !addedCIDRs.isEmpty || !removedCIDRs.isEmpty {
            log(.info, "CIDR changes detected - Added: \(addedCIDRs), Removed: \(removedCIDRs)")
            
            // Update current peers and CIDRs
            self.currentPeers = keepAlive.peerDetails
            self.currentCIDRs = newCIDRs
            
            // Update tunnel routes
            updateTunnelRoutes()
        } else {
            // Just update peers list, no route changes
            self.currentPeers = keepAlive.peerDetails
            log(.debug, "No CIDR changes, peers updated")
        }
    }
    
    private func updateTunnelRoutes() {
        guard let gateway = tunnelGateway,
              let privateIP = tunnelPrivateIP,
              let maskString = tunnelMask else {
            log(.error, "Cannot update routes: network configuration not available")
            return
        }
        
        // Create new tunnel settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: gateway)
        
        // Parse subnet mask
        let mask = parseSubnetMask(maskString)
        let ipv4Settings = NEIPv4Settings(addresses: [privateIP], subnetMasks: [mask])
        
        // Build routes list
        var routes: [NEIPv4Route] = []
        
        // Add route to gateway
        if let gatewayRoute = createRoute(to: gateway, mask: mask) {
            routes.append(gatewayRoute)
        }
        
        // Add routes for all current CIDRs
        for cidr in currentCIDRs {
            if let route = parseCIDRRoute(cidr) {
                routes.append(route)
            }
        }
        
        if !routes.isEmpty {
            ipv4Settings.includedRoutes = routes
        }
        
        settings.ipv4Settings = ipv4Settings
        
        // Configure DNS
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        settings.mtu = 1430
        
        // Update tunnel settings
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                log(.error, "Failed to update tunnel routes: \(error.localizedDescription)")
                return
            }
            
            log(.info, "Tunnel routes updated successfully - Total routes: \(routes.count)")
            
            // Start reading packets if not already started
            if !self.isReadingPackets {
                DispatchQueue.global(qos: .background).async { [weak self] in
                    guard let self = self else { return }
                    self.isReadingPackets = true
                    self.readTunnel(packetFlow: self.packetFlow)
                }
            }
        }
    }
    
    private func handleDataFrame(_ dataFrame: DataFrame) {
        let protocolNumber = NSNumber(value: AF_INET)
        writePacket(dataFrame.payload, p: protocolNumber)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log(.info, "Stopping tunnel, reason: \(reason.rawValue)")
        
        isReadingPackets = false
        rustunClient?.close()
        rustunClient = nil
        
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
              let action = message["action"] as? String else {
            completionHandler?(nil)
            return
        }
        
        switch action {
        case "getStats":
            // Return current statistics
            let response = try? JSONSerialization.data(withJSONObject: stats)
            completionHandler?(response)
            
        case "getPeers":
            // Return current peers list
            let encoder = JSONEncoder()
            if let peersData = try? encoder.encode(currentPeers) {
                completionHandler?(peersData)
            } else {
                completionHandler?(nil)
            }
            
        case "getNetworkInfo":
            // Return network information including virtual IP
            var networkInfo: [String: Any] = [:]
            if let privateIP = tunnelPrivateIP {
                networkInfo["virtualIP"] = privateIP
            }
            if let gateway = tunnelGateway {
                networkInfo["gateway"] = gateway
            }
            if let mask = tunnelMask {
                networkInfo["mask"] = mask
            }
            let response = try? JSONSerialization.data(withJSONObject: networkInfo)
            completionHandler?(response)
            
        default:
            completionHandler?(nil)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        log(.info, "Tunnel going to sleep")
        completionHandler()
    }
    
    override func wake() {
        log(.info, "Tunnel waking up")
    }
    
    // MARK: - Packet Reading
    
    /// 从虚拟网卡读取数据包
    private func readTunnel(packetFlow: NEPacketTunnelFlow) {
        guard isReadingPackets else {
            log(.info, "Stopped reading packets")
            return
        }
        
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self, self.isReadingPackets else { return }
            
            self.stats["rxPackets"]? += UInt64(packets.count)
            
            for (index, packet) in packets.enumerated() {
                // 更新接收字节数
                self.stats["rxBytes"]? += UInt64(packet.count)
                
                // 处理数据包
                self.handlePacket(packet)
                
                // 这里可以添加将数据包转发到 rustun server 的逻辑
                // 目前只是读取和记录
            }
            
            // 继续读取下一批数据包
            self.readTunnel(packetFlow: packetFlow)
        }
    }
    
    // MARK: - Packet Handling
    
    /// 处理接收到的数据包
    private func handlePacket(_ packet: Data) {
        guard packet.count >= 20 else {
            return
        }
        
        // 解析 IP 包头
        let version = (packet[0] >> 4) & 0x0F
        let headerLength = Int((packet[0] & 0x0F) * 4)
        
        guard packet.count >= headerLength else {
            return
        }
        
        // 提取源 IP 和目标 IP
        let srcIP = String(format: "%d.%d.%d.%d",
                          packet[12], packet[13], packet[14], packet[15])
        let dstIP = String(format: "%d.%d.%d.%d",
                          packet[16], packet[17], packet[18], packet[19])
        
        // 提取协议类型
        let protocolType = packet[9]
        let protocolName: String
        switch protocolType {
        case 1: protocolName = "ICMP"
        case 6: protocolName = "TCP"
        case 17: protocolName = "UDP"
        default: protocolName = "Unknown(\(protocolType))"
        }
        
        // 提取总长度
        let totalLength = (Int(packet[2]) << 8) | Int(packet[3])
        
        // 记录数据包信息
        log(.debug, "📦 Received packet: \(packet.count) bytes, IP v\(version), \(srcIP) -> \(dstIP), Protocol: \(protocolName), Total Length: \(totalLength)")
        
        // Send packet to rustun server
        do {
            try rustunClient?.sendData(packet)
        } catch {
            log(.error, "Failed to send packet to server: \(error.localizedDescription)")
        }
    }
    
    /// 写入数据包到虚拟网卡
    /// 这个方法用于将从 rustun server 接收到的数据包写入虚拟网卡
    private func writePacket(_ packet: Data, p: NSNumber) {
        packetFlow.writePackets([packet], withProtocols: [p])
        
        // 更新发送统计
        stats["txPackets"]? += 1
        stats["txBytes"]? += UInt64(packet.count)
    }
    
    // MARK: - Helper Methods
    
    private func parseSubnetMask(_ mask: String) -> String {
        // If mask is already in dotted decimal format, return it
        if mask.contains(".") {
            return mask
        }
        
        // If mask is prefix length, convert to dotted decimal
        if let prefixLength = Int(mask), prefixLength >= 0 && prefixLength <= 32 {
            let maskValue: UInt32 = (0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF
            let a = (maskValue >> 24) & 0xFF
            let b = (maskValue >> 16) & 0xFF
            let c = (maskValue >> 8) & 0xFF
            let d = maskValue & 0xFF
            return "\(a).\(b).\(c).\(d)"
        }
        
        // Default to /24
        return "255.255.255.0"
    }
    
    private func createRoute(to destination: String, mask: String) -> NEIPv4Route? {
        return NEIPv4Route(destinationAddress: destination, subnetMask: mask)
    }
    
    private func parseCIDRRoute(_ cidr: String) -> NEIPv4Route? {
        let components = cidr.split(separator: "/")
        guard components.count == 2,
              let prefixLength = Int(components[1]),
              prefixLength >= 0 && prefixLength <= 32 else {
            return nil
        }
        
        let ip = String(components[0])
        let mask = parseSubnetMask(String(prefixLength))
        return NEIPv4Route(destinationAddress: ip, subnetMask: mask)
    }
}
