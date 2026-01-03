import SwiftUI

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
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab Content
            if selectedTab == 0 {
                NetworkTab(viewModel: viewModel)
            } else {
                LogsTab()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
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
                    .fill(isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

