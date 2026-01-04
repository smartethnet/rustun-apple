import SwiftUI
#if os(macOS)

struct VPNFormView: View {
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
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
            }
            
            // Secret Key
            VStack(alignment: .leading, spacing: 6) {
                Text("Secret Key")
                    .font(.headline)
                    .fontWeight(.medium)
                SecureField("Enter your secret key", text: $cryptoKey)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
    }
    
    var isValid: Bool {
        !name.isEmpty && !serverAddress.isEmpty && !identity.isEmpty
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
