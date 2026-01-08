import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
struct LogsTab: View {
    @ObservedObject private var service = RustunClientService.shared
    @State private var searchText = ""
    @State private var autoScroll = true
    
    var filteredLogs: [String] {
        if searchText.isEmpty {
            return service.logs
        } else {
            return service.logs.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Toolbar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                
                Divider()
                    .frame(height: 16)
                
                Toggle(isOn: $autoScroll) {
                    Label("Auto", systemImage: "arrow.down.to.line")
                        .font(.caption2)
                }
                .toggleStyle(.button)
                .controlSize(.mini)
                
                Button(action: { service.logs.removeAll() }) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption2)
                }
                .controlSize(.mini)
                
                Button(action: exportLogs) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.caption2)
                }
                .controlSize(.mini)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(PlatformColors.controlBackground)
            
            Divider()
            
            // Logs content
            if filteredLogs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No logs yet" : "No matching logs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Logs will appear when connected" : "Try different keywords")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, log in
                                LogRow(log: log)
                                    .id(index)
                            }
                        }
                    }
                    .background(PlatformColors.textBackground)
                    .onChange(of: service.logs.count) { _ in
                        if autoScroll, let lastIndex = filteredLogs.indices.last {
                            withAnimation {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "rustun-logs-\(Date().timeIntervalSince1970).txt"
        panel.allowedContentTypes = [.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let logsText = service.logs.joined(separator: "\n")
                try? logsText.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

struct LogRow: View {
    let log: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(logColor)
                .frame(width: 4, height: 4)
                .padding(.top, 4)
            
            Text(log)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
    
    private var logColor: Color {
        if log.contains("❌") || log.contains("Error") || log.contains("Failed") {
            return .red
        } else if log.contains("⚠️") || log.contains("Warning") {
            return .orange
        } else if log.contains("✅") || log.contains("Success") || log.contains("Connected") {
            return .green
        } else {
            return .blue
        }
    }
}
#endif

