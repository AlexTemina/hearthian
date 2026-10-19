import SwiftUI

// MARK: - Status

struct StatusMark: View {
    let item: Item
    let isNext: Bool

    var body: some View {
        Group {
            if isNext {
                Circle().fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .padding(3)
                    .background(Circle().fill(Color.accentColor.opacity(0.22)))
            } else {
                Image(systemName: symbol).foregroundStyle(color)
            }
        }
        .frame(width: 18, height: 18)
    }

    private var symbol: String {
        switch item.status {
        case "done": "checkmark.circle.fill"
        case "moved": "arrow.uturn.right.circle"
        case "snoozed": "moon.zzz"
        case "skipped": "forward.end.circle"
        case "dropped": "xmark.circle"
        default: "circle"
        }
    }

    private var color: Color {
        switch item.status {
        case "done": .green
        case "dropped": .red.opacity(0.7)
        case "open": .secondary.opacity(0.6)
        default: .orange
        }
    }
}

struct Chip: View {
    let text: String
    var strong = false

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(strong ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(strong ? Color.accentColor : .secondary)
    }
}

// MARK: - Row

enum ComposerMode { case message, newAgent }

struct ItemRow: View {
    @EnvironmentObject private var settings: AppSettings
    let item: Item
    var isNext = false
    var showActions = true

    @State private var hover = false
    @State private var composer: ComposerMode?
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                StatusMark(item: item, isNext: isNext).padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    if item.size != nil || !item.tags.isEmpty {
                        HStack(spacing: 4) {
                            if let size = item.size { Chip(text: size, strong: true) }
                            ForEach(item.tags, id: \.self) { Chip(text: $0) }
                        }
                    }
                    Text(item.text)
                        .font(.system(size: 13, weight: isNext ? .semibold : .regular))
                        .lineSpacing(2)
                        .strikethrough(!item.isOpen, color: .secondary.opacity(0.6))
                        .foregroundStyle(item.isOpen ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if showActions {
                    HStack(spacing: 2) {
                        IconButton(help: L.jumpHelp.text, action: { Actions.jump(item) }) { RobotIcon(size: 15) }
                        IconButton(help: L.messageHelp.text, action: { toggle(.message) }) { RobotIcon(badge: .talk, size: 15) }
                        IconButton(help: L.newAgentHelp.text, action: { toggle(.newAgent) }) { RobotIcon(badge: .plus, size: 15) }
                    }
                    .opacity(hover || composer != nil ? 1 : 0)
                }
            }
            if let composer { composerView(composer) }
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(isNext ? Color.accentColor.opacity(0.07) : (hover ? Color.secondary.opacity(0.06) : .clear),
                    in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { if composer == nil { Actions.open(item) } }
        .contextMenu {
            Button(L.messageAgent.text) { toggle(.message) }
            Button(L.newAgent.text) { toggle(.newAgent) }
            Divider()
            ForEach(item.links, id: \.self) { link in
                Button("\(L.openLink.text) \(link.title)") { Actions.open(link) }
            }
            Divider()
            Button(L.copyLine.text) { Actions.copy(item) }
        }
    }

    private func toggle(_ mode: ComposerMode) {
        if composer == mode { composer = nil; return }
        draft = mode == .newAgent ? Actions.startPrompt(for: item) : ""
        composer = mode
        DispatchQueue.main.async { focused = true }
    }

    private func submit(_ mode: ComposerMode) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        switch mode {
        case .message: Actions.message(text, to: item)
        case .newAgent: Actions.newAgent(text, for: item)
        }
        composer = nil
        draft = ""
    }

    private func composerView(_ mode: ComposerMode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                RobotIcon(badge: mode == .message ? .talk : .plus, size: 12).foregroundStyle(Color.accentColor)
                Text("\(mode == .message ? L.agentFor.text : L.newAgentFor.text) \(item.target ?? "…")")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text(L.typeMessage.text).font(.callout).foregroundStyle(.tertiary).padding(.horizontal, 5).padding(.vertical, 8)
                }
                TextEditor(text: $draft)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .frame(minHeight: 54, maxHeight: 110)
            }
            .padding(4)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.35)))
            HStack {
                Spacer()
                Button(L.cancel.text) { composer = nil }.keyboardShortcut(.cancelAction)
                Button(L.send.text) { submit(mode) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(.leading, 28)
    }
}

// MARK: - Day

struct Card<Content: View>: View {
    let title: String?
    var trailing: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                HStack {
                    Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(.secondary)
                    Spacer()
                    if let trailing { Text(trailing).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                }
                .padding(.horizontal, 10)
            }
            content()
        }
        .padding(.vertical, 12).padding(.horizontal, 6)
        .background(.background.secondary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.12)))
    }
}

struct DayView: View {
    @ObservedObject var store: Store
    @EnvironmentObject private var settings: AppSettings
    var compact: Bool

    var body: some View {
        Group {
            if let day = store.day { content(day) } else { empty }
        }
        .overlay(alignment: .bottom) {
            if let failure = store.failure {
                Label(failure, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).padding(10)
                    .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    .padding(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.failure)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Text("☀️").font(.system(size: 40))
            Text(L.noDay.text).foregroundStyle(.secondary)
            Text(store.error ?? "").font(.caption.monospaced()).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(_ day: Day) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(day)
                if let focus = day.focus { focusCard(focus) }
                if !day.slots.isEmpty { slots(day) }
                Card(title: L.queue.text, trailing: "\(day.progress.done)/\(day.progress.total)") {
                    ForEach(day.queue) { ItemRow(item: $0, isNext: $0 == day.next) }
                }
                if !day.parallel.isEmpty {
                    Card(title: L.parallel.text) { ForEach(day.parallel) { ItemRow(item: $0) } }
                }
                if let waiting = day.whileWaiting { note(L.whileWaiting.text, waiting) }
                if !compact {
                    if !day.decisions.isEmpty {
                        Card(title: L.decisions.text) { ForEach(day.decisions) { ItemRow(item: $0) } }
                    }
                    if let notToday = day.notToday { note(L.notToday.text, notToday) }
                    ForEach(day.sections) { section in
                        Card(title: section.title) { ForEach(section.items) { ItemRow(item: $0) } }
                    }
                }
            }
            .padding(18)
        }
    }

    private func header(_ day: Day) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(day.eyebrow.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
                Text(L.appTitle.text).font(.system(size: 22, weight: .bold, design: .rounded))
                if let week = day.week {
                    Text(week).font(.caption).foregroundStyle(.secondary).lineLimit(compact ? 2 : nil)
                }
            }
            Spacer()
            ProgressRing(done: day.progress.done, total: day.progress.total)
        }
    }

    private func focusCard(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(L.focus.text, systemImage: "flame.fill")
                .font(.system(size: 11, weight: .heavy)).tracking(0.8)
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
            ItemRow(item: item)
        }
        .padding(.vertical, 12).padding(.horizontal, 6)
        .background(
            LinearGradient(colors: [.orange.opacity(0.14), .accentColor.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.25)))
    }

    private func slots(_ day: Day) -> some View {
        HStack(spacing: 8) {
            ForEach(day.slots) { slot in
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.caption2)
                    Text(slot.time).font(.caption.monospacedDigit().weight(.semibold))
                    Text(slot.title).font(.caption).lineLimit(1)
                }
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Color.secondary.opacity(0.1), in: Capsule())
                .help(slot.text)
            }
        }
    }

    private func note(_ title: String, _ text: String) -> some View {
        Card(title: title) {
            Text(text).font(.callout).foregroundStyle(.secondary).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
        }
    }
}

struct ProgressRing: View {
    let done: Int
    let total: Int

    var body: some View {
        let fraction = total == 0 ? 0 : Double(done) / Double(total)
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 5)
            Circle().trim(from: 0, to: fraction)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: fraction)
            Text("\(Int((fraction * 100).rounded()))%").font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
        }
        .frame(width: 46, height: 46)
    }
}

// MARK: - Menu bar

struct MenuContent: View {
    @ObservedObject var store: Store
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            DayView(store: store, compact: true)
                .frame(width: 460, height: 640)
            Divider()
            HStack(spacing: 14) {
                Button { openWindow(id: "day"); NSApp.activate(ignoringOtherApps: true) } label: {
                    Label(L.openDay.text, systemImage: "macwindow")
                }
                Button { NSWorkspace.shared.open(Store.pageFile) } label: {
                    Label(L.openInBrowser.text, systemImage: "safari")
                }
                Spacer()
                SettingsLink { Image(systemName: "gearshape") }.help(L.settings.text)
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.help(L.quit.text)
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Picker(L.language.text, selection: $settings.languageRaw) {
                Text(L.systemLanguage.text).tag(Language.system.rawValue)
                Text(L.english.text).tag(Language.en.rawValue)
                Text(L.spanish.text).tag(Language.es.rawValue)
            }
            LabeledContent("today.json", value: Store.dayFile.path).font(.caption)
            LabeledContent("config.json", value: Config.file.path).font(.caption)
        }
        .padding(20)
        .frame(width: 520)
    }
}
