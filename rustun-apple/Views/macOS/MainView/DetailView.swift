import SwiftUI

#if os(macOS)
struct DetailView: View {
    @ObservedObject var viewModel: VPNViewModel
    @ObservedObject private var service = RustunClientService.shared
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Tab Bar
            HStack(spacing: 0) {
                TabButton(title: "VPN", icon: "network", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                TabButton(title: "Logs", icon: "doc.text", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(PlatformColors.windowBackground)
            
            Divider()
            
            // Tab Content
            if selectedTab == 0 {
                NetworkTab(viewModel: viewModel)
            } else {
                LogsTab()
            }
        }
        .background(PlatformColors.windowBackground)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? PlatformColors.controlBackground : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif

