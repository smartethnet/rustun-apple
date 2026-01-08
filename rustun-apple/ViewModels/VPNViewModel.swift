import Foundation
import Combine

class VPNViewModel: ObservableObject {
    @Published var config: VPNConfig
    @Published var isConnected: Bool = false
    @Published var savedConfigs: [VPNConfig] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let service = RustunClientService.shared
    private let configKey = "vpn_config"
    private let savedConfigsKey = "vpn_saved_configs"
    
    /// Check if config is empty (no valid configuration)
    var hasValidConfig: Bool {
        !config.serverAddress.isEmpty && !config.identity.isEmpty
    }
    
    init() {
        self.config = VPNConfig()
        // Load saved configs
        self.savedConfigs = loadSavedConfigs()
        // Load current config or use default
        self.config = loadConfig() ?? VPNConfig()
        service.$status
            .sink { [weak self] status in
                self?.isConnected = (status == .connected)
            }
            .store(in: &cancellables)
    }
    
    /// Connect to server
    func connect() {
        service.connect(with: config)
    }
    
    /// Disconnect from server
    func disconnect() {
        service.disconnect()
    }
    
    /// Toggle connection
    func toggleConnection() {
        if service.status == .connected {
            disconnect()
        } else {
            connect()
        }
    }
    
    /// Save current config
    func saveConfig() {
        // Save current config
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: configKey)
        }
        
        // Add to saved configs if not already present
        if !savedConfigs.contains(where: { $0.id == config.id }) {
            savedConfigs.append(config)
            saveSavedConfigs()
        } else {
            // Update existing config in saved configs
            if let index = savedConfigs.firstIndex(where: { $0.id == config.id }) {
                savedConfigs[index] = config
                saveSavedConfigs()
            }
        }
    }
    
    /// Load a specific config
    func loadConfig(_ configToLoad: VPNConfig) {
        disconnect()
        config = configToLoad
        // Save as current config
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: configKey)
        }
    }
    
    /// Delete a specific saved config
    func deleteConfig(_ configToDelete: VPNConfig) {
        savedConfigs.removeAll { $0.id == configToDelete.id }
        saveSavedConfigs()
        
        // If deleting the current config, reset to default
        if config.id == configToDelete.id {
            disconnect()
            config = VPNConfig()
            UserDefaults.standard.removeObject(forKey: configKey)
        }
    }
    
    /// Load config from UserDefaults
    private func loadConfig() -> VPNConfig? {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let decoded = try? JSONDecoder().decode(VPNConfig.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    /// Load saved configs from UserDefaults
    private func loadSavedConfigs() -> [VPNConfig] {
        guard let data = UserDefaults.standard.data(forKey: savedConfigsKey),
              let decoded = try? JSONDecoder().decode([VPNConfig].self, from: data) else {
            return []
        }
        return decoded
    }
    
    /// Save saved configs to UserDefaults
    private func saveSavedConfigs() {
        if let encoded = try? JSONEncoder().encode(savedConfigs) {
            UserDefaults.standard.set(encoded, forKey: savedConfigsKey)
        }
    }
    
    /// Delete current config (disconnect if connected, then clear config)
    func deleteConfig() {
        disconnect()
        // Clear config
        config = VPNConfig()
        
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: configKey)
    }
}

