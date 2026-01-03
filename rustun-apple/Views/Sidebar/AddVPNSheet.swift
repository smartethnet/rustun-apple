import SwiftUI

struct AddVPNSheet: View {
    @ObservedObject var viewModel: VPNViewModel
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (VPNConfig) -> Void
    
    @State private var name: String = "My VPN Server"
    @State private var serverAddress: String = ""
    @State private var serverPort: Int = 8080
    @State private var identity: String = ""
    @State private var cryptoType: CryptoType = .chacha20
    @State private var cryptoKey: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New VPN")
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
                
                Button("Add") {
                    addVPN()
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
    
    private func addVPN() {
        let config = VPNConfig(
            name: name,
            serverAddress: serverAddress,
            serverPort: serverPort,
            identity: identity,
            cryptoType: cryptoType,
            cryptoKey: cryptoKey,
            enableP2P: true,
            keepaliveInterval: 10  
        )
        
        viewModel.config = config
        viewModel.saveConfig()
        onSave(config)
        dismiss()
    }
}

#Preview {
    AddVPNSheet(
        viewModel: VPNViewModel(),
        onSave: { _ in }
    )
}

