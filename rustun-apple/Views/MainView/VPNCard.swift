import SwiftUI

struct VPNCard: View {
    @ObservedObject var viewModel: VPNViewModel
    @ObservedObject private var service = RustunClientService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                // Name
                Text(viewModel.config.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Status
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor.opacity(0.5), radius: 2)
                    
                    Text(service.status.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                    
                    // Connection Time
                    if service.status == .connected {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(service.stats.formattedConnectedTime)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Toggle Switch (Small)
                Toggle("", isOn: Binding(
                    get: { service.status == .connected },
                    set: { _ in viewModel.toggleConnection() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .disabled(service.status == .connecting)
            }
            
            // Server Address
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("\(viewModel.config.serverAddress):\(viewModel.config.serverPort)")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            // Identity + Private IP (same row)
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text(viewModel.config.identity)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("-") // Placeholder for private_ip
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Routes
            HStack(spacing: 6) {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("Local Ciders:")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("-") 
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var statusColor: Color {
        switch service.status {
        case .connected: return .green
        case .connecting: return .blue
        case .error: return .red
        case .disconnected: return .gray
        }
    }
    
    private var borderColor: Color {
        switch service.status {
        case .connected: return .green.opacity(0.5)
        case .connecting: return .blue.opacity(0.5)
        case .error: return .red.opacity(0.5)
        case .disconnected: return Color(NSColor.separatorColor)
        }
    }
}

