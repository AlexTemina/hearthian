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
    @ObservedObject private var monitor = AgentMonitor.shared
    let item: Item
    var isNext = false
    var showActions = true
    var showStatus = true

    @State private var hover = false
    @State private var titleHover = false
    @State private var composer: ComposerMode?
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                if showStatus { StatusMark(item: item, isNext: isNext).padding(.top, 1) }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let primary = item.primary {
                            Button { Actions.open(primary) } label: {
                                Text(item.heading)
                                    .font(.system(size: 13, weight: .bold))
                                    .underline(titleHover)
                                    .multilineTextAlignment(.leading)
                            }
                            .buttonStyle(.plain)
                            .onHover { titleHover = $0 }
                            .help(primary.url)
                        } else {
                            Text(item.heading).font(.system(size: 13, weight: isNext ? .semibold : .regular))
                        }
                    }
                    .strikethrough(!item.isOpen, color: .secondary.opacity(0.6))
                    .foregroundStyle(item.isOpen ? .primary : .secondary)
                    if item.size != nil || !item.tags.isEmpty || monitor.status(for: item) != nil {
                        HStack(spacing: 4) {
                            if let status = monitor.status(for: item) { AgentPill(status: status) }
                            if let size = item.size { Chip(text: size, strong: true) }
                            ForEach(item.tags, id: \.self) { Chip(text: $0) }
                        }
                    }
                    if let detail = item.detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .lineSpacing(2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
    var inMenu = false

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
                    if !day.notToday.isEmpty {
                        Card(title: L.notToday.text) { ForEach(day.notToday) { ItemRow(item: $0) } }
                    }
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
                if inMenu {
                    Text(day.eyebrow.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
                }
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

struct WindowBar: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var windows = SlackWindows.shared

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: windows.isOpen ? "bubble.left.and.bubble.right.fill" : "moon.zzz.fill")
                .foregroundStyle(windows.isOpen ? Color.accentColor : .secondary)
            if windows.isOpen, let end = windows.windowEndsAt {
                Text("\(L.windowOpenUntil.text) \(SlackWindows.hm(end))").font(.callout)
                Spacer()
                Button(L.extendWindow.text) { windows.extend() }
                Button(L.endWindowNow.text) { windows.closeWindow() }
            } else {
                Text(windows.next.map { "\(L.nextWindow.text): \($0)" } ?? L.lastWindowBody.text).font(.callout)
                Spacer()
                Button(L.startWindowNow.text) { windows.openWindow() }
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 16).padding(.vertical, 9)
    }
}

struct MenuContent: View {
    @ObservedObject var store: Store
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            DayView(store: store, compact: true, inMenu: true)
                .frame(width: 460, height: 640)
            Divider()
            WindowBar()
            Divider()
            HStack(spacing: 14) {
                Button { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) } label: {
                    Label(L.openDay.text, systemImage: "macwindow")
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
        TabView {
            GeneralSettings().tabItem { Label(L.general.text, systemImage: "gearshape") }
            SlackSettings().tabItem { Label(L.slackWindows.text, systemImage: "bubble.left.and.bubble.right") }
        }
        .frame(width: 580)
        .environmentObject(settings)
    }
}

struct GeneralSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var atLogin = LoginItem.isOn

    var body: some View {
        Form {
            Picker(L.language.text, selection: $settings.languageRaw) {
                Text(L.systemLanguage.text).tag(Language.system.rawValue)
                Text(L.english.text).tag(Language.en.rawValue)
                Text(L.spanish.text).tag(Language.es.rawValue)
            }
            Toggle(L.launchAtLogin.text, isOn: $atLogin)
                .onChange(of: atLogin) { _, on in LoginItem.set(on); atLogin = LoginItem.isOn }
                .help(L.openAtLoginHelp.text)
            LabeledContent("today.json", value: Store.dayFile.path).font(.caption)
            LabeledContent("config.json", value: Config.file.path).font(.caption)
        }
        .formStyle(.grouped)
        .padding(8)
    }
}

struct SlackSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var windows = SlackWindows.shared
    @State private var token = Keychain.get("slack-user-token") ?? ""
    @State private var tokenSaved = false

    private var days: [(Int, L)] {
        [(1, .monday), (2, .tuesday), (3, .wednesday), (4, .thursday), (5, .friday), (6, .saturday), (7, .sunday)]
    }

    var body: some View {
        Form {
            Section {
                Toggle(L.windowsEnabled.text, isOn: $windows.schedule.enabled)
                Stepper(value: $windows.schedule.minutes, in: 5...60, step: 5) {
                    LabeledContent(L.windowLength.text, value: "\(windows.schedule.minutes) \(L.minutesUnit.text)")
                }
            }
            Section {
                ForEach(days, id: \.0) { day, name in
                    HStack {
                        Text(name.text).frame(width: 90, alignment: .leading)
                        TextField("09:20, 12:40, 16:30", text: times(day))
                            .font(.body.monospacedDigit())
                        TextField("17:00", text: dayEnd(day))
                            .font(.body.monospacedDigit())
                            .frame(width: 64)
                    }
                }
            } header: { Text(L.weekdayTimes.text) } footer: { Text(L.timesHelp.text).font(.caption) }
            Section {
                Toggle(L.openSlackAtStart.text, isOn: $windows.schedule.openSlack)
                Toggle(L.quitSlackAtEnd.text, isOn: $windows.schedule.quitSlack)
                Toggle(L.setSlackStatus.text, isOn: $windows.schedule.setStatus)
                HStack {
                    SecureField(L.slackToken.text, text: $token)
                    Button(tokenSaved ? L.saved.text : L.send.text) {
                        Keychain.set("slack-user-token", token.trimmingCharacters(in: .whitespacesAndNewlines))
                        tokenSaved = true
                    }
                }
                Text(L.slackTokenHelp.text).font(.caption).foregroundStyle(.secondary)
                if let error = windows.lastError { Text(error).font(.caption).foregroundStyle(.red) }
            }
            Section(L.statusTexts.text) {
                statusRow($windows.schedule.windowEmoji, $windows.schedule.windowStatus)
                statusRow($windows.schedule.focusEmoji, $windows.schedule.focusStatus)
                statusRow($windows.schedule.offEmoji, $windows.schedule.offStatus)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(minHeight: 620)
    }

    private func statusRow(_ emoji: Binding<String>, _ text: Binding<String>) -> some View {
        HStack {
            TextField("", text: emoji).frame(width: 90).font(.caption.monospaced())
            TextField("", text: text)
        }
    }

    private func times(_ day: Int) -> Binding<String> {
        Binding(
            get: { (windows.schedule.times[day] ?? []).joined(separator: ", ") },
            set: { value in
                let parsed = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil }
                windows.schedule.times[day] = parsed.isEmpty ? nil : parsed.sorted()
            })
    }

    private func dayEnd(_ day: Int) -> Binding<String> {
        Binding(get: { windows.schedule.dayEnds[day] ?? "" },
                set: { windows.schedule.dayEnds[day] = $0.isEmpty ? nil : $0 })
    }
}
