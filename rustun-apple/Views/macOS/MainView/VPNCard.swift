import SwiftUI

#if os(macOS)
struct VPNCard: View {
    @ObservedObject var viewModel: VPNViewModel
    @ObservedObject private var service = RustunClientService.shared
    
    // 判断当前配置是否是连接的配置
    private var isCurrentConfig: Bool {
        service.isCurrentConnect(id: viewModel.config.id)
    }
    
    // 获取显示的状态
    private var displayStatus: VPNStatus {
        if isCurrentConfig {
            return service.status
        } else {
            return .disconnected
        }
    }
    
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
                    
                    // Connection Time
                    if displayStatus == .connected && isCurrentConfig {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(service.stats.formattedConnectedTime)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Toggle Switch (Small)
                Toggle("", isOn: Binding(
                    get: { displayStatus == .connected && isCurrentConfig },
                    set: { _ in viewModel.toggleConnection() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .disabled(displayStatus == .connecting)
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
        .background(PlatformColors.controlBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var statusColor: Color {
        switch displayStatus {
        case .connected: return .green
        case .connecting: return .blue
        case .error: return .red
        case .disconnected: return .gray
        }
    }
    
    private var borderColor: Color {
        switch displayStatus {
        case .connected: return .green.opacity(0.5)
        case .connecting: return .blue.opacity(0.5)
        case .error: return .red.opacity(0.5)
        case .disconnected: return PlatformColors.separator
        }
    }
}
#endif

