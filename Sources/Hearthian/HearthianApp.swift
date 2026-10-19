import SwiftUI

@main
struct HearthianApp: App {
    @StateObject private var store = Store()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(store: store)
                .environmentObject(settings)
                .onAppear { Actions.store = store }
        } label: {
            Text(store.menuTitle)
        }
        .menuBarExtraStyle(.window)

        Window("Hearthian", id: "day") {
            DayView(store: store, compact: false)
                .environmentObject(settings)
                .frame(minWidth: 540, minHeight: 680)
                .onAppear { Actions.store = store }
        }
        .defaultSize(width: 640, height: 860)

        Settings {
            SettingsView().environmentObject(settings)
        }
    }
}
