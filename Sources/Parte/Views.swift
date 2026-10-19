import SwiftUI

struct ItemRow: View {
    let item: Item
    let isNext: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(isNext ? "●" : item.icon)
                .foregroundStyle(isNext ? Color.accentColor : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                if item.size != nil || !item.tags.isEmpty {
                    Text(([item.size].compactMap { $0 } + item.tags).joined(separator: " · "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Text(item.text)
                    .font(isNext ? .body.weight(.semibold) : .body)
                    .strikethrough(!item.isOpen, color: .secondary)
                    .foregroundStyle(item.isOpen ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if item.target != nil || item.links.isEmpty == false {
                Button("🤖") { Actions.jump(item) }
                    .buttonStyle(.plain)
                    .help("Ir a su agente en Orca")
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { Actions.open(item) }
        .contextMenu {
            Button("Mensaje al agente activo…") { Actions.message(item) }
            Button("Agente nuevo…") { Actions.newAgent(item) }
            Divider()
            ForEach(item.links, id: \.self) { link in
                Button("Abrir \(link.title)") { Actions.open(link) }
            }
            Divider()
            Button("Copiar línea") { Actions.copy(item) }
        }
    }
}

struct DayView: View {
    @ObservedObject var store: Store
    var compact: Bool

    var body: some View {
        if let day = store.day {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(day)
                    if let una = day.laUna { laUna(una) }
                    if !day.slots.isEmpty { slots(day) }
                    queue(day)
                    if !day.parallel.isEmpty { group("En paralelo", day.parallel, next: nil) }
                    if let waiting = day.whileWaiting { note("Mientras esperas", waiting) }
                    if !compact {
                        if !day.decisions.isEmpty { group("Decisiones", day.decisions, next: nil) }
                        if let notToday = day.notToday { note("Hoy no", notToday) }
                        ForEach(day.sections) { section in
                            group(section.title, section.items, next: nil)
                        }
                    }
                }
                .padding(16)
            }
        } else {
            VStack(spacing: 8) {
                Text("☀️").font(.largeTitle)
                Text(store.error ?? "Cargando…").foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }

    private func header(_ day: Day) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.eyebrow.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack {
                Text("Parte del día").font(.title2.weight(.bold))
                Spacer()
                Text("\(day.progress.done)/\(day.progress.total)").font(.title3.monospacedDigit())
            }
            ProgressView(value: Double(day.progress.done), total: Double(max(day.progress.total, 1)))
            if let week = day.week { Text(week).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func laUna(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LA UNA").font(.caption.weight(.bold)).foregroundStyle(Color.accentColor)
            ItemRow(item: item, isNext: false)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func slots(_ day: Day) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(day.slots) { slot in
                HStack(alignment: .firstTextBaseline) {
                    Text(slot.time).font(.callout.monospacedDigit()).foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                    Text(slot.title).font(.callout.weight(.semibold))
                }
            }
        }
    }

    private func queue(_ day: Day) -> some View {
        group("Cola", day.queue, next: day.next)
    }

    private func group(_ title: String, _ items: [Item], next: Item?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            ForEach(items) { item in
                ItemRow(item: item, isNext: item == next)
                Divider().opacity(0.4)
            }
        }
    }

    private func note(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MenuContent: View {
    @ObservedObject var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            DayView(store: store, compact: true)
                .frame(width: 420, height: 560)
            Divider()
            HStack {
                Button("Abrir parte") {
                    openWindow(id: "day")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("En el navegador") { NSWorkspace.shared.open(Store.pageFile) }
                Spacer()
                Button("Salir") { NSApp.terminate(nil) }
            }
            .padding(10)
        }
    }
}
