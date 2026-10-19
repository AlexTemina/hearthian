import SwiftUI

@main
struct HearthianApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @StateObject private var store = Store()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        Window("Hearthian", id: "main") {
            MainWindow(store: store)
                .environmentObject(settings)
                .frame(minWidth: 760, minHeight: 620)
                .onAppear { Actions.store = store }
        }
        .defaultSize(width: 1040, height: 820)

        MenuBarExtra {
            MenuContent(store: store)
                .environmentObject(settings)
                .onAppear { Actions.store = store }
        } label: {
            Text(store.menuTitle)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(settings)
        }
    }
}

/// Closing the window keeps Hearthian alive in the menu bar; the Dock icon brings the window back.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
