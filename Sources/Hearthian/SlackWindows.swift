import AppKit
import Foundation
import UserNotifications

/// The few moments of the day Slack is read. Everything here is configured in Settings.
struct SlackSchedule: Codable, Equatable {
    var enabled = true
    var minutes = 20
    /// Times per weekday, 1 = Monday … 7 = Sunday, as "HH:mm".
    /// Every two hours or so; Monday to Thursday the third one waits for lunch to end.
    var times: [Int: [String]] = [1: ["09:20", "11:20", "13:40", "15:40"], 2: ["09:20", "11:20", "13:40", "15:40"],
                                  3: ["09:20", "11:20", "13:40", "15:40"], 4: ["09:20", "11:20", "13:40", "15:40"],
                                  5: ["09:00", "11:00", "13:00", "15:00"]]
    /// End of the working day, per weekday, for the status after the last window.
    var dayEnds: [Int: String] = [1: "17:00", 2: "17:00", 3: "17:00", 4: "17:00", 5: "16:00"]
    var openSlack = true
    var quitSlack = false
    /// Between windows Slack stays open and macOS Focus silences it, through the Shortcuts below.
    var focusBetweenWindows = true
    var setStatus = true
    var windowStatus = "Slack window, {minutes} min"
    var windowEmoji = ":window:"
    var focusStatus = "Deep work, back at {next}. Huddle or call me if it cannot wait"
    var focusEmoji = ":fire:"
    var offStatus = "Off for today, back tomorrow"
    var offEmoji = ":wave:"

    static let key = "slackSchedule"

    static func load() -> SlackSchedule {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(SlackSchedule.self, from: data) else { return SlackSchedule() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    static func weekday(_ date: Date = .now) -> Int {
        (Calendar(identifier: .gregorian).component(.weekday, from: date) + 5) % 7 + 1
    }
}

@MainActor
final class SlackWindows: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = SlackWindows()

    @Published var schedule = SlackSchedule.load() { didSet { schedule.save() } }
    @Published private(set) var windowEndsAt: Date?
    @Published var lastError: String?

    private var timer: Timer?
    private var fired: Set<String> = []
    private var endTask: Task<Void, Never>?

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let extend = UNNotificationAction(identifier: "extend", title: L.extendWindow.text)
        let skip = UNNotificationAction(identifier: "skip", title: L.skipWindow.text)
        center.setNotificationCategories([UNNotificationCategory(identifier: "window", actions: [extend, skip],
                                                                 intentIdentifiers: [])])
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
        syncStatus()
    }

    var isOpen: Bool { windowEndsAt.map { $0 > .now } ?? false }

    /// The next window today, if any.
    var next: String? {
        let now = Self.hm(.now)
        return (schedule.times[SlackSchedule.weekday()] ?? []).sorted().first { $0 > now }
    }

    private func tick() {
        guard schedule.enabled else { return }
        let now = Self.hm(.now)
        let day = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        for t in schedule.times[SlackSchedule.weekday()] ?? [] where t == now {
            let id = "\(day)-\(t)"
            if fired.insert(id).inserted { openWindow() }
        }
    }

    func openWindow(minutes: Int? = nil) {
        let length = minutes ?? schedule.minutes
        windowEndsAt = Date.now.addingTimeInterval(TimeInterval(length * 60))
        notify(L.windowStarts.text, L.windowStartsBody.text.replacingOccurrences(of: "{minutes}", with: "\(length)"),
               category: "window")
        if schedule.openSlack { open() }
        focus(until: nil)
        status(schedule.windowStatus.replacingOccurrences(of: "{minutes}", with: "\(length)"), schedule.windowEmoji,
               until: windowEndsAt)
        scheduleEnd()
    }

    func extend(by minutes: Int = 10) {
        guard let end = windowEndsAt else { return openWindow(minutes: minutes) }
        windowEndsAt = max(end, .now).addingTimeInterval(TimeInterval(minutes * 60))
        status(schedule.windowStatus.replacingOccurrences(of: "{minutes}", with: "\(minutes)"), schedule.windowEmoji,
               until: windowEndsAt)
        scheduleEnd()
    }

    func closeWindow() {
        endTask?.cancel()
        windowEndsAt = nil
        if schedule.quitSlack { quit() }
        let weekday = SlackSchedule.weekday()
        if let next {
            focus(until: Self.date(next))
            notify(L.windowEnds.text, L.windowEndsBody.text.replacingOccurrences(of: "{next}", with: next))
            status(schedule.focusStatus.replacingOccurrences(of: "{next}", with: next), schedule.focusEmoji,
                   until: Self.date(next))
        } else {
            notify(L.windowEnds.text, L.lastWindowBody.text)
            status(schedule.offStatus, schedule.offEmoji, until: schedule.dayEnds[weekday].flatMap { Self.date($0) })
        }
    }

    private func scheduleEnd() {
        endTask?.cancel()
        guard let end = windowEndsAt else { return }
        endTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.closeWindow()
        }
    }

    // MARK: Slack

    private func open() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.tinyspeck.slackmacgap") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    private func quit() {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.tinyspeck.slackmacgap").forEach { $0.terminate() }
    }

    /// users.profile.set with the user's own token when there is one in the Keychain, the Raycast Slack extension otherwise.
    private func status(_ text: String, _ emoji: String, until: Date?) {
        guard schedule.setStatus else { return }
        guard let token = Keychain.get("slack-user-token") else { return raycastStatus(text, emoji, until: until) }
        var request = URLRequest(url: URL(string: "https://slack.com/api/users.profile.set")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        let profile: [String: Any] = ["status_text": text, "status_emoji": emoji,
                                      "status_expiration": Int(until?.timeIntervalSince1970 ?? 0)]
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["profile": profile])
        URLSession.shared.dataTask(with: request) { data, _, error in
            let reply = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let problem = error?.localizedDescription ?? ((reply?["ok"] as? Bool) == true ? nil : reply?["error"] as? String)
            Task { @MainActor in self.lastError = problem.map { "Slack: \($0)" } }
        }.resume()
    }

    /// macOS Focus between windows: "Hearthian Focus" gets the minutes until the next window, "Hearthian Focus Off"
    /// ends it. Both are Shortcuts he creates once; without them Slack is left as it is and the error says so.
    private func focus(until: Date?) {
        guard schedule.focusBetweenWindows else { return }
        let name = until == nil ? "Hearthian Focus Off" : "Hearthian Focus"
        let minutes = until.map { max(1, Int(($0.timeIntervalSinceNow / 60).rounded(.up))) } ?? 0
        DispatchQueue.global(qos: .utility).async {
            let input = FileManager.default.temporaryDirectory.appendingPathComponent("hearthian-focus.txt")
            try? "\(minutes)".write(to: input, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name, "--input-path", input.path]
            process.standardError = Pipe()
            let ok = (try? process.run()) != nil && { process.waitUntilExit(); return process.terminationStatus == 0 }()
            if !ok { Task { @MainActor in self.lastError = "Focus: no Shortcut \"\(name)\" in the Shortcuts app" } }
        }
    }

    /// The Raycast Slack extension (mommertf/slack) sets the status with the user's own session: no Slack app to approve.
    private func raycastStatus(_ text: String, _ emoji: String, until: Date?) {
        let minutes = until.map { max(1, Int(($0.timeIntervalSinceNow / 60).rounded(.up))) } ?? 0
        let args = ["statusText": text, "emoji": emoji, "expiration": "\(minutes)"]
        guard let json = try? JSONSerialization.data(withJSONObject: args), let value = String(data: json, encoding: .utf8),
              var url = URLComponents(string: "raycast://extensions/mommertf/slack/set-status") else { return }
        url.queryItems = [URLQueryItem(name: "arguments", value: value)]
        guard let link = url.url, NSWorkspace.shared.urlForApplication(toOpen: link) != nil else {
            lastError = "Slack: no token and no Raycast to set the status"
            return
        }
        NSWorkspace.shared.open(link)
    }

    /// On launch, the status the schedule says it should have now, so a restart between windows does not leave it stale.
    private func syncStatus() {
        guard schedule.enabled else { return }
        let weekday = SlackSchedule.weekday()
        let times = (schedule.times[weekday] ?? []).sorted()
        let now = Self.hm(.now)
        guard let first = times.first, now >= first else { return }
        let inWindow = times.contains { t in
            guard let start = Self.date(t) else { return false }
            return Date.now >= start && Date.now < start.addingTimeInterval(TimeInterval(schedule.minutes * 60))
        }
        guard !inWindow else { return }
        if let next {
            focus(until: Self.date(next))
            status(schedule.focusStatus.replacingOccurrences(of: "{next}", with: next), schedule.focusEmoji, until: Self.date(next))
        } else if let end = schedule.dayEnds[weekday], now < end {
            status(schedule.offStatus, schedule.offEmoji, until: Self.date(end))
        }
    }

    // MARK: Notifications

    private func notify(_ title: String, _ body: String, category: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category { content.categoryIdentifier = category }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler handler: @escaping () -> Void) {
        let action = response.actionIdentifier
        Task { @MainActor in
            switch action {
            case "extend": self.extend()
            case "skip": self.closeWindow()
            default: break
            }
            handler()
        }
    }

    // MARK: Time

    static func hm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func date(_ hm: String) -> Date? {
        let parts = hm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: .now)
    }
}
