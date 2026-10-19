import ServiceManagement
import SwiftUI

enum Page: Hashable {
    case today, parallel, decisions, notToday
    case section(String)
}

struct MainWindow: View {
    @ObservedObject var store: Store
    @EnvironmentObject private var settings: AppSettings
    @State private var page: Page? = .today

    var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            if let day = store.day {
                detail(day, page ?? .today)
                    .id(page)
            } else {
                DayView(store: store, compact: false)
            }
        }
        .navigationTitle(store.day?.eyebrow ?? "Hearthian")
        .overlay(alignment: .bottom) { failure }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $page) {
            if let day = store.day {
                Section {
                    row(.today, L.appTitle.text, "flame.fill", "\(day.progress.done)/\(day.progress.total)")
                    if !day.parallel.isEmpty { row(.parallel, L.parallel.text, "arrow.triangle.branch", "\(day.parallel.count)") }
                    if !day.decisions.isEmpty {
                        row(.decisions, L.decisions.text, "questionmark.bubble", "\(day.decisions.filter(\.isOpen).count)")
                    }
                    if day.notToday != nil { row(.notToday, L.notToday.text, "moon.zzz", nil) }
                }
                Section(L.map.text) {
                    ForEach(day.sections) { section in
                        row(.section(section.title), stripIcon(section.title), symbol(for: section.title),
                            "\(section.items.filter(\.isOpen).count)")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            if let day = store.day {
                HStack(spacing: 10) {
                    ProgressRing(done: day.progress.done, total: day.progress.total)
                        .scaleEffect(0.8).frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(day.next?.text ?? "✓").font(.caption.weight(.semibold)).lineLimit(2)
                        Text(L.next.text).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
    }

    private func row(_ value: Page, _ title: String, _ icon: String, _ badge: String?) -> some View {
        Label(title, systemImage: icon)
            .badge(badge.map { Text($0) })
            .tag(value)
    }

    private func stripIcon(_ title: String) -> String {
        let parts = title.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, parts[0].unicodeScalars.allSatisfy({ !$0.properties.isAlphabetic }) else { return title }
        return String(parts[1])
    }

    private func symbol(for title: String) -> String {
        switch title.first {
        case "🧭": "point.topleft.down.to.point.bottomright.curvepath"
        case "🔴": "exclamationmark.circle"
        case "⏳": "hourglass"
        case "🟢": "bolt.circle"
        case "📅": "calendar"
        case "🌙": "moon.stars"
        case "🏆": "trophy"
        case "🎯": "scope"
        default: "list.bullet"
        }
    }

    // MARK: Detail

    @ViewBuilder
    private func detail(_ day: Day, _ page: Page) -> some View {
        switch page {
        case .today:
            DayView(store: store, compact: true)
        case .parallel:
            list(L.parallel.text, day.parallel)
        case .decisions:
            list(L.decisions.text, day.decisions)
        case .notToday:
            text(L.notToday.text, day.notToday ?? "")
        case .section(let title):
            list(title, day.sections.first(where: { $0.title == title })?.items ?? [])
        }
    }

    private func list(_ title: String, _ items: [Item]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(stripIcon(title)).font(.system(size: 24, weight: .bold, design: .rounded))
                Card(title: nil) { ForEach(items) { ItemRow(item: $0) } }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private func text(_ title: String, _ body: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.system(size: 24, weight: .bold, design: .rounded))
                Text(body).font(.body).lineSpacing(3).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    @ViewBuilder private var failure: some View {
        if let failure = store.failure {
            Label(failure, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).padding(10)
                .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                .padding(12)
        }
    }
}

/// Start at login through the system's own Login Items.
enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Hearthian login item: \(error.localizedDescription)")
        }
    }
}
