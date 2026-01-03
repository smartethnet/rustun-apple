import NetworkExtension
import Foundation
import Darwin

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var stats: [String: Any] = [
        "rxBytes": 0,
        "txBytes": 0,
        "rxPackets": 0,
        "txPackets": 0
    ]
    private var isReadingPackets = false
    
    override init() {
        super.init()
        log(.info,"Initialing tunnel provider")
    }
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        log(.info, "Starting tunnel...")
        
        // Get server address from configuration
        var serverAddress = "127.0.0.1"
        if let protocolConfig = protocolConfiguration as? NETunnelProviderProtocol {
            if let address = protocolConfig.serverAddress {
                serverAddress = address
            }
        }
        
        // Setup basic tunnel network settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        // Configure virtual IP address
        // Using a default private IP range
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        settings.ipv4Settings = ipv4Settings
        
        // Configure DNS
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        
        // Set tunnel network settings
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else {
                completionHandler(NSError(domain: "PacketTunnelProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                return
            }
            
            if let error = error {
                log(.error, "Failed to set tunnel settings: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            
            log(.info, "Tunnel network settings configured successfully")
            
            // Start reading packets from tunnel
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                self.isReadingPackets = true
                self.readTunnel(packetFlow: self.packetFlow)
            }
            
            completionHandler(nil)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log(.info, "Stopping tunnel, reason: \(reason.rawValue)")
        
        isReadingPackets = false
        
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
            
            // 更新接收统计
            if let rxPackets = self.stats["rxPackets"] as? Int {
                self.stats["rxPackets"] = rxPackets + packets.count
            }
            
            for (index, packet) in packets.enumerated() {
                // 更新接收字节数
                if let rxBytes = self.stats["rxBytes"] as? UInt64 {
                    self.stats["rxBytes"] = rxBytes + UInt64(packet.count)
                }
                
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
        
        // TODO: 在这里实现将数据包转发到 rustun server 的逻辑
        // 1. 解析数据包
        // 2. 加密数据包（如果需要）
        // 3. 通过 TCP/UDP 发送到 rustun server
    }
    
    /// 写入数据包到虚拟网卡
    /// 这个方法用于将从 rustun server 接收到的数据包写入虚拟网卡
    private func writePacket(_ packet: Data, p: NSNumber) {
        packetFlow.writePackets([packet], withProtocols: [p])
        
        // 更新发送统计
        if let txPackets = stats["txPackets"] as? Int {
            stats["txPackets"] = txPackets + 1
        }
        if let txBytes = stats["txBytes"] as? UInt64 {
            stats["txBytes"] = txBytes + UInt64(packet.count)
        }
    }
}
