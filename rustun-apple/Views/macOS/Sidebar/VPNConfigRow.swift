import SwiftUI
#if os(macOS)

struct VPNConfigRow: View {
    let config: VPNConfig
    let status: VPNStatus
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .overlay(
                    Circle()
                        .stroke(status == .connected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                )
                .shadow(color: statusColor.opacity(status == .connected ? 0.8 : 0.5), radius: status == .connected ? 3 : 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(config.name)
                    .font(.system(size: 13, weight: .medium))
                
                Text("\(config.serverAddress):\(config.serverPort)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if config.enableP2P {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch status {
        case .connected: return Color(red: 0.2, green: 0.8, blue: 0.2) // 更鲜艳的绿色
        case .connecting: return Color(red: 0.0, green: 0.5, blue: 1.0) // 更亮的蓝色
        case .error: return Color(red: 1.0, green: 0.3, blue: 0.3) // 更鲜艳的红色
        case .disconnected: return .gray.opacity(0.3)
        }
    }
}

#endif
