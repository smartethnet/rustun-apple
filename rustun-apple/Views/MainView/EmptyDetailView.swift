import SwiftUI

struct EmptyDetailView: View {
    @ObservedObject var viewModel: VPNViewModel
    @Binding var selectedConfigId: UUID?
    @State private var showingAddSheet = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "network.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No VPN Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first VPN configuration to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingAddSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Create VPN")
                        .font(.system(size: 15, weight: .medium))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingAddSheet) {
            AddVPNSheet(
                viewModel: viewModel,
                onSave: { config in
                    selectedConfigId = config.id
                }
            )
        }
    }
}

