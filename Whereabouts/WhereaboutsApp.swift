import SwiftUI

@main
struct WhereaboutsApp: App {
    @StateObject private var viewModel = WhereaboutsViewModel()

    var body: some Scene {
        // MenuBarExtra(.window) renders the panel using the OS-native presentation —
        // Liquid Glass on macOS Tahoe, vibrancy on earlier releases. It handles:
        //   • No arrow / correct border radius for the current OS
        //   • Click-outside dismissal natively
        //   • Status-bar title updates via @StateObject
        MenuBarExtra(
            content: {
                PopoverView()
                    .environmentObject(viewModel)
            },
            label: {
                // Plain text label — city, country code (e.g. "San Jose, US")
                Text(viewModel.menuBarTitle)
            }
        )
        .menuBarExtraStyle(.window)
    }
}
