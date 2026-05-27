//
//  StudentHubApp.swift
//  StudentHub
//

import SwiftUI

@main
struct StudentHubApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
        // Fenêtre de préférences native macOS accessible via ⌘,
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(settings)
                .frame(width: 700, height: 600)
        }
        #endif
    }
}
