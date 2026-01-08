import SwiftUI

#if os(macOS)
struct SettingsTab: View {
    @State private var settings = AppSettings.load()
    @State private var model: AIModel = .gpt
    @State private var modelKey: String = ""
    @State private var hasUnsavedChanges = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon and Name
                VStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text("Rustun")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("VPN Client for macOS & iOS")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)
                
                Divider()
                    .padding(.horizontal, 32)
                
                // Version Info
                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(title: "Version", value: getAppVersion())
                    InfoRow(title: "Build", value: getBuildNumber())
                }
                .padding(.horizontal, 32)
                
                Divider()
                    .padding(.horizontal, 32)
                
                // AI Model Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("AI Model Settings")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Model")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Picker("", selection: $model) {
                                ForEach(AIModel.allCases, id: \.self) { modelType in
                                    Text(modelType.displayName).tag(modelType)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: model) { _ in hasUnsavedChanges = true }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("API Key")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            SecureField("Enter your API key", text: $modelKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: modelKey) { _ in hasUnsavedChanges = true }
                        }
                    }
                    
                    if hasUnsavedChanges {
                        HStack {
                            Spacer()
                            Button("Save") {
                                saveSettings()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 32)
                
                Divider()
                    .padding(.horizontal, 32)
                
                // Links
                VStack(alignment: .leading, spacing: 12) {
                    Text("Resources")
                        .font(.headline)
                    
                    Link("GitHub Repository", destination: URL(string: "https://github.com/smartethnet/rustun-apple") ?? URL(string: "https://github.com/smartethnet")!)
                    Link("Documentation", destination: URL(string: "https://github.com/smartethnet") ?? URL(string: "https://github.com/smartethnet")!)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        settings = AppSettings.load()
        model = settings.model
        modelKey = settings.modelKey
        hasUnsavedChanges = false
    }
    
    private func saveSettings() {
        settings.model = model
        settings.modelKey = modelKey
        settings.save()
        hasUnsavedChanges = false
    }
    
    private func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Unknown"
    }
    
    private func getBuildNumber() -> String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return build
        }
        return "Unknown"
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
#endif

