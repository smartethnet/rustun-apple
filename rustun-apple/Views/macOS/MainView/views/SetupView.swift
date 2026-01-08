import SwiftUI

#if os(macOS)
struct SetupView: View {
    @ObservedObject var viewModel: VPNViewModel
    @State private var showingAddVPN = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "network.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No VPN Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add your first VPN configuration to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingAddVPN = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Add VPN")
                        .font(.system(size: 15, weight: .medium))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlatformColors.windowBackground)
        .sheet(isPresented: $showingAddVPN) {
            AddVPN(viewModel: viewModel)
        }
    }
}
#endif

