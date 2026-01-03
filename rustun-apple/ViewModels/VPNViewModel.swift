import Foundation
import Combine

class VPNViewModel: ObservableObject {
    @Published var config: VPNConfig
    @Published var savedConfigs: [VPNConfig] = []
    @Published var isConnected: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let service = RustunClientService.shared
    private let configsKey = "saved_vpn_configs"
    
    init() {
        // Load default or last used config
        self.config = VPNConfig()
        loadConfigs()
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
        if isConnected {
            disconnect()
        } else {
            connect()
        }
    }
    
    /// Save current config
    func saveConfig() {
        // Update existing or add new
        if let index = savedConfigs.firstIndex(where: { $0.id == config.id }) {
            savedConfigs[index] = config
        } else {
            savedConfigs.append(config)
        }
        
        saveConfigs()
    }
    
    /// Delete a config
    func deleteConfig(_ config: VPNConfig) {
        savedConfigs.removeAll { $0.id == config.id }
        saveConfigs()
    }
    
    /// Load a saved config
    func loadConfig(_ config: VPNConfig) {
        self.config = config
    }
    
    /// Save configs to UserDefaults
    private func saveConfigs() {
        if let encoded = try? JSONEncoder().encode(savedConfigs) {
            UserDefaults.standard.set(encoded, forKey: configsKey)
        }
    }
    
    /// Load configs from UserDefaults
    private func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: configsKey),
           let decoded = try? JSONDecoder().decode([VPNConfig].self, from: data) {
            savedConfigs = decoded
            if let first = decoded.first {
                config = first
            }
        }
    }
}

