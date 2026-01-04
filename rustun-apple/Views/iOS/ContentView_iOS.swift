import SwiftUI

#if os(iOS)
struct ContentView_iOS: View {
    @StateObject private var viewModel = VPNViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NetworkTab(viewModel: viewModel)
                .tabItem {
                    Label("Network", systemImage: "network")
                }
                .tag(0)
            
            PeersTab()
                .tabItem {
                    Label("Peers", systemImage: "person.2")
                }
                .tag(1)
            
            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
    }
}

struct NetworkTab: View {
    @ObservedObject var viewModel: VPNViewModel
    @ObservedObject private var service = RustunClientService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        VPNCard(viewModel: viewModel)
                        
                        StatisticsCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Network")
        }
    }
}

struct PeersTab: View {
    @ObservedObject private var service = RustunClientService.shared
    
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Peers")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text("\(clients.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(PlatformColors.secondarySystemBackground)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    if service.status == .connected {
                        if clients.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary.opacity(0.6))
                                
                                Text("No other peers")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("Peers will appear here when they connect to the VPN")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(clients) { client in
                                    ClientCard(client: client)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "network.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            Text("Not connected")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Connect to VPN to see your peers")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                    }
                }
                .padding(.bottom, 16)
            }
            .refreshable {
                if service.status == .connected {
                    service.requestPeersFromProvider()
                }
            }
            .navigationTitle("Peers")
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
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: VPNViewModel
    
    var body: some View {
        NavigationStack {
            Form {
                Section("VPN Configuration") {
                    TextField("Name", text: $viewModel.config.name)
                    TextField("Server Address", text: $viewModel.config.serverAddress)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Server Port", value: $viewModel.config.serverPort, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Identity", text: $viewModel.config.identity)
                    
                    Picker("Encryption", selection: $viewModel.config.cryptoType) {
                        ForEach(CryptoType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    SecureField("Crypto Key", text: $viewModel.config.cryptoKey)
                    
                    Toggle("Enable P2P", isOn: $viewModel.config.enableP2P)
                    
                    TextField("Keepalive Interval", value: $viewModel.config.keepaliveInterval, format: .number)
                        .keyboardType(.numberPad)
                }
                
                Section("Saved Configurations") {
                    ForEach(viewModel.savedConfigs) { config in
                        Button(action: {
                            viewModel.loadConfig(config)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(config.name)
                                        .foregroundColor(.primary)
                                    Text("\(config.serverAddress):\(config.serverPort)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if viewModel.config.id == config.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteConfig(viewModel.savedConfigs[index])
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        viewModel.saveConfig()
                    }) {
                        HStack {
                            Spacer()
                            Text("Save Configuration")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct VPNCard: View {
    @ObservedObject var viewModel: VPNViewModel
    @ObservedObject private var service = RustunClientService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.config.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor.opacity(0.5), radius: 2)
                    
                    if service.status == .connected {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(service.stats.formattedConnectedTime)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle("", isOn: Binding(
                    get: { service.status == .connected },
                    set: { _ in viewModel.toggleConnection() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .disabled(service.status == .connecting)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("\(viewModel.config.serverAddress):\(viewModel.config.serverPort)")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text(viewModel.config.identity)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
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

struct StatisticsCard: View {
    @ObservedObject private var service = RustunClientService.shared
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            StatCard(
                icon: "arrow.down.circle.fill",
                title: "Downloaded",
                value: service.stats.formattedRxBytes,
                color: .green
            )
            
            StatCard(
                icon: "arrow.up.circle.fill",
                title: "Uploaded",
                value: service.stats.formattedTxBytes,
                color: .orange
            )
            
            StatCard(
                icon: "tray.and.arrow.down.fill",
                title: "RX Packets",
                value: "\(service.stats.rxPackets)",
                color: .blue
            )
            
            StatCard(
                icon: "tray.and.arrow.up.fill",
                title: "TX Packets",
                value: "\(service.stats.txPackets)",
                color: .purple
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
        .background(PlatformColors.secondarySystemBackground)
        .cornerRadius(8)
    }
}

struct ClientCard: View {
    let client: ClientInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
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
            
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(client.privateIP)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
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

