import SwiftUI

/// Root view for the app. Currently displays the component showcase
/// for visual verification of the design system (Milestone 0.2).
/// This will be replaced with the real navigation flow in Milestone 1.
struct ContentView: View {
    var body: some View {
        ComponentShowcase()
    }
}

#Preview {
    ContentView()
}
