import SwiftUI

#if os(macOS)
struct NetworkTab: View {
    @ObservedObject var viewModel: VPNViewModel
    @ObservedObject private var service = RustunClientService.shared
    @State private var showingSettingsSheet = false
    
    // 将 peers 转换为 ClientInfo
    private var clients: [ClientInfo] {
        service.peers.map { peer in
            ClientInfo(
                identity: peer.identity,
                privateIP: peer.privateIP,
                cidrs: peer.ciders,
                isP2P: !peer.ipv6.isEmpty && peer.port > 0,
                lastActive: peer.lastActive
            )
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    VPNCard(viewModel: viewModel, showingSettingsSheet: $showingSettingsSheet)
                        .frame(maxWidth: 350)
                    
                    StatisticsCard(stats: service.stats)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Clients Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Peers")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(clients.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(PlatformColors.separator.opacity(0.3))
                            .cornerRadius(6)
                    }
                    
                    if service.status == .connected {
                        if clients.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("No other peers")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Peers will appear here when they connect")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(PlatformColors.controlBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(PlatformColors.separator, lineWidth: 1)
                            )
                        } else {
                            // Clients grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(clients) { client in
                                    ClientCard(client: client)
                                }
                            }
                        }
                    } else {
                        // Not connected
                        VStack(spacing: 12) {
                            Image(systemName: "network.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Not connected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Connect to VPN to see your peers")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(PlatformColors.controlBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(PlatformColors.separator, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            if service.status == .connected {
                service.requestPeersFromProvider()
            }
        }
        .onChange(of: service.status) { newStatus in
            if newStatus == .connected {
                service.requestPeersFromProvider()
            }
        }
        .sheet(isPresented: $showingSettingsSheet) {
            EditVPN(viewModel: viewModel)
        }
    }
}

// MARK: - VPNCard
private struct VPNCard: View {
    @ObservedObject var viewModel: VPNViewModel
    @ObservedObject private var service = RustunClientService.shared
    @Binding var showingSettingsSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                // Name with Edit button
                HStack(spacing: 6) {
                    Text(viewModel.config.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        showingSettingsSheet = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit VPN Configuration")
                }
                
                Spacer()
                
                // Status
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor.opacity(0.5), radius: 2)
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
        .background(PlatformColors.controlBackground)
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
        case .disconnected: return PlatformColors.separator
        }
    }
}

// MARK: - StatisticsCard
private struct StatisticsCard: View {
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

private struct StatCard: View {
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

// MARK: - ClientCard
private struct ClientCard: View {
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
            
            // Last Active Time
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("Last active: \(client.lastActiveText)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(PlatformColors.secondarySystemBackground)
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
    let lastActive: UInt64
    
    var lastActiveText: String {
        if lastActive == 0 {
            return "-"
        }
        
        let now = Date().timeIntervalSince1970
        let lastActiveTime = TimeInterval(lastActive)
        let elapsed = now - lastActiveTime
        
        if elapsed < 60 {
            return "\(Int(elapsed))s ago"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m ago"
        } else if elapsed < 86400 {
            return "\(Int(elapsed / 3600))h ago"
        } else {
            return "\(Int(elapsed / 86400))d ago"
        }
    }
}

#endif

