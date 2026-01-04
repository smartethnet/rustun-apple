import SwiftUI

struct ContentView: View {
    #if os(macOS)
    var body: some View {
        ContentView_macOS()
    }
    #elseif os(iOS)
    var body: some View {
        ContentView_iOS()
    }
    #endif
}

#Preview {
    ContentView()
}
