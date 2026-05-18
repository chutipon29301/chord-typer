import SwiftUI
import AppKit
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "AppMenu")

@main
struct ChordTyperApp: App {
    @AppStorage("chordTyperEnabled") private var chordTyperEnabled: Bool = true
    @AppStorage("englishEnabled")    private var englishEnabled: Bool = true
    @AppStorage("thaiEnabled")       private var thaiEnabled: Bool = true

    private var menuBarIcon: String {
        chordTyperEnabled ? "keyboard.fill" : "keyboard.badge.ellipsis"
    }

    var body: some Scene {
        MenuBarExtra("ChordTyper", systemImage: menuBarIcon) {
            Toggle("Enable ChordTyper", isOn: $chordTyperEnabled)

            Divider()

            Menu("Dictionaries") {
                Toggle("English", isOn: $englishEnabled)
                Toggle("Thai", isOn: $thaiEnabled)
            }

            Divider()

            Button("Settings...") {
                logger.info("Settings tapped — not implemented yet")
            }

            Button("Open Dictionary Folder") {
                if let url = Bundle.main.resourceURL?
                                .appendingPathComponent("dictionaries") {
                    NSWorkspace.shared.open(url)
                } else {
                    logger.error("dictionaries directory not found in bundle")
                }
            }

            Divider()

            Button("Quit ChordTyper") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
