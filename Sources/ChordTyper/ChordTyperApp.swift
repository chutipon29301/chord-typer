import SwiftUI

@main
struct ChordTyperApp: App {
    var body: some Scene {
        MenuBarExtra("ChordTyper", systemImage: "keyboard") {
            Text("ChordTyper is running")
                .padding()
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}
