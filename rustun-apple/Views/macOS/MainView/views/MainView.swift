import SwiftUI

#if os(macOS)
struct MainView: View {
    @ObservedObject var viewModel: VPNViewModel
    @ObservedObject private var service = RustunClientService.shared
    
    @State private var selectedTab = 0
    @State private var showingSettingsPrompt = false
    
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
                
                TabButton(title: "Settings", icon: "gearshape", isSelected: selectedTab == 2) {
                    selectedTab = 2
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
            } else if selectedTab == 1 {
                LogsTab()
            } else {
                SettingsTab()
            }
            
            
            HStack {
                Spacer()
                Button(action: openAIChat) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Ask AI")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .background(PlatformColors.windowBackground)
        .alert("AI Settings Required", isPresented: $showingSettingsPrompt) {
            Button("Cancel", role: .cancel) { }
            Button("Go to Settings") {
                selectedTab = 2 // Switch to Settings tab
            }
        } message: {
            Text("Please configure your AI model and API key in Settings before using AI features.")
        }
    }
    
    private func openAIChat() {
        // Check if AI settings are configured
        let settings = AppSettings.load()
        if settings.modelKey.isEmpty {
            // Show prompt to configure settings
            showingSettingsPrompt = true
            return
        }
        
        // Show AI chat window (独立窗口)
        AIChatWindowManager.shared.showWindow()
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

