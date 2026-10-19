import Foundation
import SwiftUI

/// What the agents of one worktree are doing, read from Orca's own signals and never from
/// anything an agent has to remember to write:
/// - a Claude terminal whose title starts with a spinner is working; `✳` means it is waiting;
/// - `lastOutputAt` tells a live spinner from one that froze;
/// - Orca's unread flag says an agent finished and nobody looked yet. It is the only signal for
///   "needs you": `lastOutputAt` also moves when Orca redraws a terminal, so it cannot tell a
///   finished agent from a repainted one.
enum AgentState: String {
    case thinking, needsYou, idle, stuck, none

    var rank: Int {
        switch self {
        case .needsYou: 4
        case .stuck: 3
        case .thinking: 2
        case .idle: 1
        case .none: 0
        }
    }
}

struct AgentStatus: Equatable {
    var state: AgentState
    var agents: Int
    var working: Int
    var lastOutput: Date?
    var title: String?
}

@MainActor
final class AgentMonitor: ObservableObject {
    static let shared = AgentMonitor()

    /// A spinner with no output for this long is shown as possibly stuck.
    nonisolated static let stuckAfter: TimeInterval = 10 * 60

    @Published private(set) var byWorktree: [String: AgentStatus] = [:]
    @Published private(set) var worktrees: [Orca.Worktree] = []
    @Published private(set) var lastPoll: Date?
    @Published private(set) var error: String?

    private var timer: Timer?
    private var polling = false

    func start() {
        poll()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in Task { @MainActor in self?.poll() } }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func status(for item: Item) -> AgentStatus? {
        guard let w = Orca.worktree(for: item, in: worktrees) else { return nil }
        return byWorktree[w.id]
    }

    func poll() {
        guard !polling else { return }
        polling = true
        DispatchQueue.global(qos: .utility).async {
            let result = Result { (try Orca.worktrees(), try Orca.terminals()) }
            Task { @MainActor in
                self.polling = false
                switch result {
                case .success(let (worktrees, terminals)):
                    self.worktrees = worktrees
                    self.byWorktree = Self.derive(worktrees, terminals, now: .now)
                    self.error = nil
                    self.lastPoll = .now
                case .failure(let error):
                    self.error = error.localizedDescription
                }
            }
        }
    }

    nonisolated static func derive(_ worktrees: [Orca.Worktree], _ terminals: [Orca.Terminal], now: Date)
        -> [String: AgentStatus] {
        var out: [String: AgentStatus] = [:]
        for w in worktrees {
            let agents = terminals.filter { $0.worktreeId == w.id && $0.connected && isAgent($0) }
            guard !agents.isEmpty else {
                out[w.id] = AgentStatus(state: .none, agents: 0, working: 0, lastOutput: nil, title: nil)
                continue
            }
            let last = agents.compactMap(\.lastOutputAt).max().map { Date(timeIntervalSince1970: $0 / 1000) }
            let spinning = agents.filter { !isWaiting($0) }
            let live = spinning.filter { t in
                guard let at = t.lastOutputAt else { return false }
                return now.timeIntervalSince(Date(timeIntervalSince1970: at / 1000)) < stuckAfter
            }
            let state: AgentState
            if w.isUnread == true && live.isEmpty {
                state = .needsYou
            } else if !live.isEmpty {
                state = .thinking
            } else if !spinning.isEmpty {
                state = .stuck
            } else {
                state = .idle
            }
            let shown = (live.first ?? agents.max { ($0.lastOutputAt ?? 0) < ($1.lastOutputAt ?? 0) })?.title
            out[w.id] = AgentStatus(state: state, agents: agents.count, working: live.count, lastOutput: last,
                                    title: shown.map(stripGlyph))
        }
        return out
    }

    nonisolated static func isAgent(_ t: Orca.Terminal) -> Bool {
        t.agentIdentity != nil || (t.title ?? "").hasPrefix("✳")
    }

    nonisolated static func isWaiting(_ t: Orca.Terminal) -> Bool {
        (t.title ?? "").hasPrefix("✳")
    }

    nonisolated static func stripGlyph(_ title: String) -> String {
        guard let first = title.unicodeScalars.first, !first.properties.isAlphabetic, !CharacterSet.decimalDigits.contains(first)
        else { return title }
        return String(title.drop(while: { !$0.isLetter && !$0.isNumber })).trimmingCharacters(in: .whitespaces)
    }
}

/// A small pill with the agent state of an item's worktree.
struct AgentPill: View {
    @EnvironmentObject private var settings: AppSettings
    let status: AgentStatus

    var body: some View {
        if status.state != .none {
            HStack(spacing: 4) {
                icon
                Text(label).font(.system(size: 10.5, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
            .help(status.title ?? "")
        }
    }

    @ViewBuilder private var icon: some View {
        switch status.state {
        case .thinking: ProgressView().controlSize(.mini).scaleEffect(0.7).frame(width: 10, height: 10)
        case .needsYou: Image(systemName: "bell.fill").font(.system(size: 9))
        case .stuck: Image(systemName: "questionmark.circle.fill").font(.system(size: 9))
        default: Image(systemName: "moon.fill").font(.system(size: 9))
        }
    }

    private var label: String {
        switch status.state {
        case .thinking: status.working > 1 ? "\(L.agentThinking.text) ×\(status.working)" : L.agentThinking.text
        case .needsYou: L.agentNeedsYou.text
        case .stuck: L.agentStuck.text
        case .idle: L.agentIdle.text
        case .none: ""
        }
    }

    private var color: Color {
        switch status.state {
        case .thinking: .blue
        case .needsYou: .orange
        case .stuck: .gray
        default: .secondary
        }
    }
}

/// Every worktree with an agent and what it is doing: the page to check the monitor against reality.
struct AgentsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var monitor: AgentMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L.agents.text).font(.system(size: 24, weight: .bold, design: .rounded))
                    Spacer()
                    if let at = monitor.lastPoll { Text("\(L.updatedAt.text) \(Self.time(at))").font(.caption).foregroundStyle(.secondary) }
                }
                if let error = monitor.error { Text(error).font(.caption).foregroundStyle(.red) }
                Card(title: nil) {
                    ForEach(rows, id: \.0.id) { worktree, status in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(worktree.displayName).font(.system(size: 13, weight: .bold))
                                Text(status.title ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if let issue = worktree.linkedLinearIssue { Chip(text: issue) }
                            Text(status.lastOutput.map(Self.ago) ?? "").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            AgentPill(status: status)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 10)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var rows: [(Orca.Worktree, AgentStatus)] {
        monitor.worktrees.compactMap { w in monitor.byWorktree[w.id].flatMap { $0.state == .none ? nil : (w, $0) } }
            .sorted { ($0.1.state.rank, $0.1.lastOutput ?? .distantPast) > ($1.1.state.rank, $1.1.lastOutput ?? .distantPast) }
    }

    static func time(_ d: Date) -> String { SlackWindows.hm(d) }

    static func ago(_ d: Date) -> String {
        let s = Int(Date.now.timeIntervalSince(d))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h"
    }
}
