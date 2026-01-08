import SwiftUI

#if os(macOS)
struct EditVPN: View {
    @ObservedObject var viewModel: VPNViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var serverAddress: String
    @State private var serverPort: Int
    @State private var identity: String
    @State private var cryptoType: CryptoType
    @State private var cryptoKey: String
    @State private var enableP2P: Bool
    @State private var keepaliveInterval: Int
    @State private var showingDeleteConfirmation = false
    
    private var isValid: Bool {
        !name.isEmpty && !serverAddress.isEmpty && !identity.isEmpty
    }
    
    init(viewModel: VPNViewModel) {
        self.viewModel = viewModel
        _name = State(initialValue: viewModel.config.name)
        _serverAddress = State(initialValue: viewModel.config.serverAddress)
        _serverPort = State(initialValue: viewModel.config.serverPort)
        _identity = State(initialValue: viewModel.config.identity)
        _cryptoType = State(initialValue: viewModel.config.cryptoType)
        _cryptoKey = State(initialValue: viewModel.config.cryptoKey)
        _enableP2P = State(initialValue: viewModel.config.enableP2P)
        _keepaliveInterval = State(initialValue: viewModel.config.keepaliveInterval)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit VPN Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Form
            ScrollView {
                VStack(spacing: 20) {
                    EditVPNForm(
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
            VStack(spacing: 12) {
                // Delete Button (at top, left-aligned)
                HStack {
                    Button(action: {
                        // Show confirmation alert
                        showingDeleteConfirmation = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text("Delete VPN Configuration")
                        }
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Divider()
                
                // Save/Cancel Buttons
                HStack {
                    Spacer()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Save") {
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
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
                .padding()
            }
            .alert("Delete VPN Configuration", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteConfig()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this VPN configuration? This action cannot be undone.")
            }
        }
        .frame(width: 500, height: 520)
    }
}

// MARK: - SettingsForm
private struct EditVPNForm: View {
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
                TextField("my-client", text: $identity)
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

extension NumberFormatter {
    static var portFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 65535
        return formatter
    }
}
#endif

