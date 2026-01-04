import SwiftUI

#if os(macOS)
struct NetworkTab: View {
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
    
    // 将 peers 转换为 ClientInfo
    private var clients: [ClientInfo] {
        if isCurrentConfig {
            return service.peers.map { peer in
                ClientInfo(
                    identity: peer.identity,
                    privateIP: peer.privateIP,
                    cidrs: peer.ciders,
                    isP2P: !peer.ipv6.isEmpty && peer.port > 0,
                    lastActive: peer.lastActive
                )
            }
        } else {
            return []
        }
    }
    
    // 获取显示的统计数据
    private var displayStats: VPNStats {
        if isCurrentConfig {
            return service.stats
        } else {
            return VPNStats()
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    VPNCard(viewModel: viewModel)
                        .frame(maxWidth: 350)
                    
                    StatisticsCard(stats: displayStats)
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
                    
                    if displayStatus == .connected {
                        let displayClients = clients
                        
                        if displayClients.isEmpty {
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
                                ForEach(displayClients) { client in
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
            // 初始加载 peers
            if displayStatus == .connected && isCurrentConfig {
                service.requestPeersFromProvider()
            }
        }
        .onChange(of: service.status) { newStatus in
            if newStatus == .connected && isCurrentConfig {
                service.requestPeersFromProvider()
            }
        }
        .onChange(of: viewModel.config.id) { _ in
            // 切换配置时，如果是当前连接的配置，刷新 peers
            if isCurrentConfig && displayStatus == .connected {
                service.requestPeersFromProvider()
            }
        }
    }
}

#endif

