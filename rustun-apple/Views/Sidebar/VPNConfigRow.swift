import SwiftUI

struct VPNConfigRow: View {
    let config: VPNConfig
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(isActive ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            
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
}

