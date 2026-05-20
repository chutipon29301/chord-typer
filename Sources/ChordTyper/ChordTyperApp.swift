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
                guard let resourceURL = Bundle.main.resourceURL else {
                    logger.error("Bundle resourceURL is nil — cannot locate dictionaries")
                    return
                }
                let dictionariesURL = resourceURL.appendingPathComponent("dictionaries")
                if FileManager.default.fileExists(atPath: dictionariesURL.path) {
                    NSWorkspace.shared.open(dictionariesURL)
                } else {
                    logger.warning("Dictionaries folder does not exist at expected path: \(dictionariesURL.path, privacy: .public)")
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
