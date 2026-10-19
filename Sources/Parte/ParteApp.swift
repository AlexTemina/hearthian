import SwiftUI

@main
struct ParteApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(store: store)
        } label: {
            Text(store.menuTitle)
        }
        .menuBarExtraStyle(.window)

        Window("Parte del día", id: "day") {
            DayView(store: store, compact: false)
                .frame(minWidth: 520, minHeight: 640)
        }
        .defaultSize(width: 620, height: 820)
    }
}
