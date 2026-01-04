import SwiftUI

#if os(macOS)
struct SidebarView: View {
    @ObservedObject var viewModel: VPNViewModel
    @ObservedObject private var service = RustunClientService.shared
    
    @Binding var selectedConfigId: UUID?
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    
    // 获取配置的状态
    private func getStatus(for config: VPNConfig) -> VPNStatus {
        // 只有当前配置真正连接时，才返回连接状态
        if service.isCurrentConnect(id: config.id) {
            return service.status
        }
        return .disconnected
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedConfigId) {
                ForEach(viewModel.savedConfigs) { config in
                    VPNConfigRow(
                        config: config,
                        status: getStatus(for: config)
                    )
                    .tag(config.id)
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            SidebarToolbar(
                showingAddSheet: $showingAddSheet,
                showingEditSheet: $showingEditSheet,
                canDelete: selectedConfigId != nil,
                onDelete: deleteSelectedConfig
            )
        }
        .frame(minWidth: 240)
        .onChange(of: selectedConfigId) { newId in
            if let newId = newId,
               let config = viewModel.savedConfigs.first(where: { $0.id == newId }) {
                viewModel.loadConfig(config)
            }
        }
        .onAppear {
            if selectedConfigId == nil, let first = viewModel.savedConfigs.first {
                selectedConfigId = first.id
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddVPNSheet(
                viewModel: viewModel,
                onSave: { config in
                    selectedConfigId = config.id
                }
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            if let config = viewModel.savedConfigs.first(where: { $0.id == selectedConfigId }) {
                EditVPNSheet(
                    viewModel: viewModel,
                    config: config,
                    onSave: { config in
                        selectedConfigId = config.id
                    }
                )
            }
        }
    }
    
    private func deleteSelectedConfig() {
        guard let selectedId = selectedConfigId,
              let config = viewModel.savedConfigs.first(where: { $0.id == selectedId }) else {
            return
        }
        
        guard service.status != .connected || viewModel.config.id != config.id else {
            return
        }
        
        viewModel.deleteConfig(config)
        
        if let first = viewModel.savedConfigs.first {
            selectedConfigId = first.id
        } else {
            selectedConfigId = nil
        }
    }
}

struct SidebarToolbar: View {
    @Binding var showingAddSheet: Bool
    @Binding var showingEditSheet: Bool
    let canDelete: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Button(action: { showingAddSheet = true }) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add VPN")
            
            Button(action: onDelete) {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(!canDelete)
            .help("Delete VPN")
            
            Spacer()
            
            Button(action: { showingEditSheet = true }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .disabled(!canDelete)
            .help("Edit VPN")
        }
        .padding(8)
        .background(PlatformColors.controlBackground)
    }
}
#endif

