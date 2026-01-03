import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = VPNViewModel()
    @State private var selectedConfigId: UUID?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: viewModel,
                selectedConfigId: $selectedConfigId
            )
        } detail: {
            if let _ = selectedConfigId {
                DetailView(viewModel: viewModel)
            } else {
                EmptyDetailView(
                    viewModel: viewModel,
                    selectedConfigId: $selectedConfigId
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    ContentView()
}
