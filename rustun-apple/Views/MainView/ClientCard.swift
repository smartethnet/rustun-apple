import SwiftUI

struct ClientCard: View {
    let client: ClientInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Identity + P2P Badge
            HStack(spacing: 8) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.5), radius: 2)
                
                Text(client.identity)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if client.isP2P {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 8))
                        Text("P2P")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.15))
                    )
                    .foregroundColor(.green)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 8))
                        Text("Relay")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.opacity(0.15))
                    )
                    .foregroundColor(.orange)
                }
            }
            
            // Private IP
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(client.privateIP)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Routes (CIDRs)
            if !client.cidrs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("Routes:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(client.cidrs.joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    private var statusColor: Color {
        client.isP2P ? .green : .orange
    }
    
    private var borderColor: Color {
        client.isP2P ? Color.green.opacity(0.3) : Color.orange.opacity(0.3)
    }
}

struct ClientInfo: Identifiable {
    let id = UUID()
    let identity: String
    let privateIP: String
    let cidrs: [String]
    let isP2P: Bool
}

