import SwiftUI

#if os(macOS)
struct AddVPN: View {
    @ObservedObject var viewModel: VPNViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var serverAddress: String = ""
    @State private var serverPort: Int = 8080
    @State private var identity: String = ""
    @State private var cryptoType: CryptoType = .chacha20
    @State private var cryptoKey: String = ""
    @State private var enableP2P: Bool = true
    @State private var keepaliveInterval: Int = 10
    
    private var isValid: Bool {
        !name.isEmpty && !serverAddress.isEmpty && !identity.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add VPN Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Form
            ScrollView {
                VStack(spacing: 20) {
                    AddVPNForm(
                        name: $name,
                        serverAddress: $serverAddress,
                        serverPort: $serverPort,
                        identity: $identity,
                        cryptoType: $cryptoType,
                        cryptoKey: $cryptoKey
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Advanced Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Advanced Settings")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Enable P2P", isOn: $enableP2P)
                            
                            HStack {
                                Text("Keepalive Interval (seconds)")
                                Spacer()
                                TextField("", value: $keepaliveInterval, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 12)
                    .background(PlatformColors.controlBackground)
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                }
            }
            
            Divider()
            
            // Actions
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add") {
                    createConfig()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 520)
    }
    
    private func createConfig() {
        viewModel.config.name = name
        viewModel.config.serverAddress = serverAddress
        viewModel.config.serverPort = serverPort
        viewModel.config.identity = identity
        viewModel.config.cryptoType = cryptoType
        viewModel.config.cryptoKey = cryptoKey
        viewModel.config.enableP2P = enableP2P
        viewModel.config.keepaliveInterval = keepaliveInterval
        viewModel.saveConfig()
        dismiss()
    }
}

// MARK: - AddVPNForm
private struct AddVPNForm: View {
    @Binding var name: String
    @Binding var serverAddress: String
    @Binding var serverPort: Int
    @Binding var identity: String
    @Binding var cryptoType: CryptoType
    @Binding var cryptoKey: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // VPN Name
            VStack(alignment: .leading, spacing: 6) {
                Text("VPN Name")
                    .font(.headline)
                    .fontWeight(.medium)
                TextField("Rustun", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Server Address
            VStack(alignment: .leading, spacing: 6) {
                Text("Server Address")
                    .font(.headline)
                    .fontWeight(.medium)
                TextField("192.168.1.100", text: $serverAddress)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Server Port
            VStack(alignment: .leading, spacing: 6) {
                Text("Server Port")
                    .font(.headline)
                    .fontWeight(.medium)
                TextField("8080", value: $serverPort, formatter: NumberFormatter.portFormatter)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Identity
            VStack(alignment: .leading, spacing: 6) {
                Text("Identity")
                    .font(.headline)
                    .fontWeight(.medium)
                TextField("headquarters", text: $identity)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Encryption Type
            VStack(alignment: .leading, spacing: 6) {
                Text("Encryption Type")
                    .font(.headline)
                    .fontWeight(.medium)
                Picker("", selection: $cryptoType) {
                    ForEach(CryptoType.allCases, id: \.self) { type in
                        Text(type == .plain ? "None" : type.displayName).tag(type)
                    }
                }
                .labelsHidden()
            }
            
            // Secret Key (only show when not plain)
            if cryptoType != .plain {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Secret Key")
                        .font(.headline)
                        .fontWeight(.medium)
                    SecureField("Enter your secret key", text: $cryptoKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding()
    }
}

#endif

