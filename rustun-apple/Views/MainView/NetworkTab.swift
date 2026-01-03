import SwiftUI

struct NetworkTab: View {
    @ObservedObject var viewModel: VPNViewModel
    @ObservedObject private var service = RustunClientService.shared
    @State private var clients: [ClientInfo] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    VPNCard(viewModel: viewModel)
                        .frame(maxWidth: 350)
                    
                    StatisticsCard()
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
                            .background(Color(NSColor.separatorColor).opacity(0.3))
                            .cornerRadius(6)
                    }
                    
                    if service.status == .connected {
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
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
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
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

