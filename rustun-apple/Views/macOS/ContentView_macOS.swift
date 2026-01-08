import SwiftUI

#if os(macOS)
struct ContentView_macOS: View {
    @StateObject private var viewModel = VPNViewModel()
    
    var body: some View {
        if viewModel.hasValidConfig {
            MainView(viewModel: viewModel)
        } else {
            SetupView(viewModel: viewModel)
        }
    }
}
#endif

