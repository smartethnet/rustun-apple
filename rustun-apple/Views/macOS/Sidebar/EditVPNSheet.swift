import SwiftUI
#if os(macOS)

struct EditVPNSheet: View {
    @ObservedObject var viewModel: VPNViewModel
    @Environment(\.dismiss) private var dismiss
    
    let config: VPNConfig
    let onSave: (VPNConfig) -> Void
    
    @State private var name: String
    @State private var serverAddress: String
    @State private var serverPort: Int
    @State private var identity: String
    @State private var cryptoType: CryptoType
    @State private var cryptoKey: String
    
    init(viewModel: VPNViewModel, config: VPNConfig, onSave: @escaping (VPNConfig) -> Void) {
        self.viewModel = viewModel
        self.config = config
        self.onSave = onSave
        
        // Initialize state from existing config
        _name = State(initialValue: config.name)
        _serverAddress = State(initialValue: config.serverAddress)
        _serverPort = State(initialValue: config.serverPort)
        _identity = State(initialValue: config.identity)
        _cryptoType = State(initialValue: config.cryptoType)
        _cryptoKey = State(initialValue: config.cryptoKey)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit VPN")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Form
            VPNFormView(
                name: $name,
                serverAddress: $serverAddress,
                serverPort: $serverPort,
                identity: $identity,
                cryptoType: $cryptoType,
                cryptoKey: $cryptoKey
            )
            
            Spacer()
            
            Divider()
            
            // Actions
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    saveVPN()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }
            .padding()
        }
        .frame(width: 500, height: 520)
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !serverAddress.isEmpty && !identity.isEmpty
    }
    
    private func saveVPN() {
        let updatedConfig = VPNConfig(
            id: config.id,
            name: name,
            serverAddress: serverAddress,
            serverPort: serverPort,
            identity: identity,
            cryptoType: cryptoType,
            cryptoKey: cryptoKey,
            enableP2P: config.enableP2P,
            keepaliveInterval: config.keepaliveInterval
        )
        
        viewModel.config = updatedConfig
        viewModel.saveConfig()
        onSave(updatedConfig)
        dismiss()
    }
}

#Preview {
    EditVPNSheet(
        viewModel: VPNViewModel(),
        config: VPNConfig(
            name: "Test Server",
            serverAddress: "192.168.1.100",
            serverPort: 8080,
            identity: "test-client",
            cryptoType: .chacha20,
            cryptoKey: "secret",
            enableP2P: true,
            keepaliveInterval: 10
        ),
        onSave: { _ in }
    )
}

#endif
