import SwiftUI

#if os(macOS)
struct StatisticsCard: View {
    let stats: VPNStats
    
    init(stats: VPNStats? = nil) {
        self.stats = stats ?? RustunClientService.shared.stats
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            StatCard(
                icon: "arrow.down.circle.fill",
                title: "Downloaded",
                value: stats.formattedRxBytes,
                color: Color(hex: "10b981")
            )
            
            StatCard(
                icon: "arrow.up.circle.fill",
                title: "Uploaded",
                value: stats.formattedTxBytes,
                color: Color(hex: "f59e0b")
            )
            
            StatCard(
                icon: "tray.and.arrow.down.fill",
                title: "RX Packets",
                value: "\(stats.rxPackets)",
                color: Color(hex: "3b82f6")
            )
            
            StatCard(
                icon: "tray.and.arrow.up.fill",
                title: "TX Packets",
                value: "\(stats.txPackets)",
                color: Color(hex: "8b5cf6")
            )
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(PlatformColors.controlBackground)
        .cornerRadius(8)
    }
}
#endif

