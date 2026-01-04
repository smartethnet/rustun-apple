import Foundation
import Combine
import NetworkExtension

/// Service to manage Rustun client using NETunnelProvider
class RustunClientService: ObservableObject {
    @Published var status: VPNStatus = .disconnected
    @Published var stats: VPNStats = VPNStats()
    @Published var peers: [PeerDetail] = []
    @Published var logs: [String] = []
    @Published var errorMessage: String?
    
    private var tunnelManager: NETunnelProviderManager?
    private var statsTimer: Timer?
    private var connectTime: Date?
    private var statusObserver: NSObjectProtocol?
    
    private var config: VPNConfig?
    private var pendingConnectConfig: VPNConfig?
    private var statusCancellable: AnyCancellable?
    
    static let shared = RustunClientService()
    
    private init() {
        loadTunnelManager()
        observeStatusChanges()
    }
    
    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func connect(with config: VPNConfig) {
        // 如果当前已连接，且是不同配置，先断开
        if status != .disconnected {
            if let currentConfig = self.config, currentConfig.id != config.id {
                // 断开当前连接，然后连接新配置
                disconnectAndConnect(config)
                return
            } else if status == .connecting {
                errorMessage = "Already connecting"
                return
            } else if status == .connected {
                // 已经是同一个配置，不需要重新连接
                return
            }
        }
        
        self.config = config
        
        status = .connecting
        errorMessage = nil
        logs = []
        
        addLog("🚀 Starting VPN connection...")
        addLog("📋 Server: \(config.serverAddress):\(config.serverPort)")
        addLog("🔐 Encryption: \(config.cryptoType.displayName)")
        
        createOrUpdateTunnelManager(with: config) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.status = .error
                    self.errorMessage = error.localizedDescription
                    self.addLog("❌ Failed to create tunnel: \(error.localizedDescription)")
                }
                return
            }
            
            // Start the tunnel
            self.startTunnel { [weak self] error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        self.status = .error
                        self.errorMessage = error.localizedDescription
                        self.addLog("❌ Failed to start tunnel: \(error.localizedDescription)")
                    } else {
                        self.connectTime = Date()
                        self.startStatsTimer()
                        self.addLog("✅ Tunnel started successfully")
                    }
                }
            }
        }
    }
    
    /// Disconnect from server
    func disconnect() {
        guard let manager = tunnelManager else {
            status = .disconnected
            return
        }
        
        addLog("🔌 Disconnecting...")
        
        guard let session = manager.connection as? NETunnelProviderSession else {
            status = .disconnected
            return
        }
        
        session.stopTunnel()
        
        // Stop stats timer
        statsTimer?.invalidate()
        statsTimer = nil
        connectTime = nil
        self.config = nil
        
        addLog("✅ Disconnected")
    }
    
    /// Disconnect current connection and connect to new config
    private func disconnectAndConnect(_ newConfig: VPNConfig) {
        addLog("🔄 Switching VPN connection...")
        
        // Store the new config to connect after disconnection
        pendingConnectConfig = newConfig
        
        // Observe status changes to connect when disconnected
        statusCancellable = $status
            .dropFirst() // Skip current status
            .sink { [weak self] newStatus in
                guard let self = self else { return }
                
                if newStatus == .disconnected, let config = self.pendingConnectConfig {
                    // Disconnected, now connect to new config
                    self.pendingConnectConfig = nil
                    self.statusCancellable?.cancel()
                    self.statusCancellable = nil
                    self.connect(with: config)
                }
            }
        
        // Start disconnection
        disconnect()
    }
    
    /// Create or update tunnel manager with configuration
    private func createOrUpdateTunnelManager(with config: VPNConfig, completion: @escaping (Error?) -> Void) {
        let manager: NETunnelProviderManager
        
        if let existingManager = tunnelManager {
            manager = existingManager
        } else {
            manager = NETunnelProviderManager()
        }
        
        // Create protocol configuration
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = "com.beyondnetwork.rustun-apple.tunnel-provider"
        protocolConfiguration.serverAddress = config.serverAddress
        protocolConfiguration.username = config.identity
        
        // Store rustun-specific configuration in providerConfiguration
        var providerConfig: [String: Any] = [:]
        providerConfig["serverAddress"] = config.serverAddress
        providerConfig["serverPort"] = config.serverPort
        providerConfig["identity"] = config.identity
        providerConfig["cryptoType"] = config.cryptoType.rawValue
        providerConfig["cryptoKey"] = config.cryptoKey
        providerConfig["enableP2P"] = config.enableP2P
        providerConfig["keepaliveInterval"] = config.keepaliveInterval
        
        protocolConfiguration.providerConfiguration = providerConfig as NSDictionary as! [String : Any]
        
        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = config.name.isEmpty ? "Rustun VPN" : config.name
        manager.isEnabled = true
        
        // Save the manager
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            // Load the manager to get the full configuration
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error = error {
                    completion(error)
                    return
                }
                
                if let savedManager = managers?.first(where: { $0.localizedDescription == manager.localizedDescription }) {
                    self?.tunnelManager = savedManager
                    completion(nil)
                } else {
                    self?.tunnelManager = manager
                    completion(nil)
                }
            }
        }
    }
    
    /// Start the tunnel
    private func startTunnel(completion: @escaping (Error?) -> Void) {
        guard let manager = tunnelManager else {
            completion(NSError(domain: "RustunClientService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tunnel manager not initialized"]))
            return
        }
        
        guard let session = manager.connection as? NETunnelProviderSession else {
            completion(NSError(domain: "RustunClientService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid tunnel session"]))
            return
        }
        
        do {
            try session.startTunnel(options: nil)
            completion(nil)
        } catch {
            completion(error)
        }
    }
    
    /// Load existing tunnel manager
    private func loadTunnelManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                self.addLog("⚠️ Failed to load tunnel managers: \(error.localizedDescription)")
                return
            }
            
            if let manager = managers?.first {
                self.tunnelManager = manager
                self.updateStatusFromManager()
            }
        }
    }
    
    /// Observe status changes
    private func observeStatusChanges() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusFromManager()
        }
    }
    
    /// Update status from tunnel manager
    private func updateStatusFromManager() {
        guard let manager = tunnelManager,
              let session = manager.connection as? NETunnelProviderSession else {
            status = .disconnected
            return
        }
        
        switch session.status {
        case .invalid:
            status = .disconnected
        case .disconnected:
            status = .disconnected
            statsTimer?.invalidate()
            statsTimer = nil
            connectTime = nil
        case .connecting:
            status = .connecting
        case .connected:
            status = .connected
            if connectTime == nil {
                connectTime = Date()
                startStatsTimer()
            }
        case .reasserting:
            status = .connecting
        case .disconnecting:
            status = .disconnected
        @unknown default:
            status = .disconnected
        }
    }
    
    /// Start statistics timer
    private func startStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    /// Update statistics
    private func updateStats() {
        guard let connectTime = connectTime else { return }
        stats.connectedTime = Date().timeIntervalSince(connectTime)
        
        // Request stats from tunnel provider
        requestStatsFromProvider()
    }
    
    /// Request statistics from tunnel provider
    private func requestStatsFromProvider() {
        guard let manager = tunnelManager,
              let session = manager.connection as? NETunnelProviderSession,
              session.status == .connected else {
            return
        }
        
        // Send message to tunnel provider to request stats
        let message = ["action": "getStats"]
        guard let messageData = try? JSONSerialization.data(withJSONObject: message) else {
            return
        }
        
        do {
            try session.sendProviderMessage(messageData) { [weak self] responseData in
                guard let self = self,
                      let data = responseData,
                      let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }
                addLog("📋 Stats: RxBytes: \(response["rxBytes"]), TxBytes: \(response["txBytes"])")
                DispatchQueue.main.async {
                    if let rxBytes = response["rxBytes"] as? UInt64 {
                        self.stats.rxBytes = rxBytes
                    }
                    if let txBytes = response["txBytes"] as? UInt64 {
                        self.stats.txBytes = txBytes
                    }
                    if let rxPackets = response["rxPackets"] as? UInt64 {
                        self.stats.rxPackets = rxPackets
                    }
                    if let txPackets = response["txPackets"] as? UInt64 {
                        self.stats.txPackets = txPackets
                    }
                    if let p2pConnections = response["p2pConnections"] as? Int {
                        self.stats.p2pConnections = p2pConnections
                    }
                    if let relayConnections = response["relayConnections"] as? Int {
                        self.stats.relayConnections = relayConnections
                    }
                }
            }
        } catch {
        }
        
        // Also request peers
        requestPeersFromProvider()
    }
    
    /// Request peers list from tunnel provider
    func requestPeersFromProvider() {
        guard let manager = tunnelManager,
              let session = manager.connection as? NETunnelProviderSession,
              session.status == .connected else {
            return
        }
        
        // Send message to tunnel provider to request peers
        let message = ["action": "getPeers"]
        guard let messageData = try? JSONSerialization.data(withJSONObject: message) else {
            return
        }
        
        do {
            try session.sendProviderMessage(messageData) { [weak self] responseData in
                guard let self = self,
                      let data = responseData else {
                    return
                }
                
                let decoder = JSONDecoder()
                if let peersList = try? decoder.decode([PeerDetail].self, from: data) {
                    DispatchQueue.main.async {
                        self.peers = peersList
                        self.addLog("👥 Updated peers: \(peersList.count) peers")
                    }
                }
            }
        } catch {
            addLog("❌ Failed to request peers: \(error.localizedDescription)")
        }
    }
    
    /// Add log entry
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        logs.append(logEntry)
        
        // Keep only last 1000 lines
        if logs.count > 1000 {
            logs.removeFirst(logs.count - 1000)
        }
    }
    
    func isCurrentConnect(id: UUID) -> Bool {
        guard let config = self.config else {return false}
        return config.id == id
    }
}


