import AppKit
import Foundation

/// What a row can do. Orca calls run off the main thread; failures surface in the store.
@MainActor
enum Actions {
    static weak var store: Store?

    static func open(_ item: Item) {
        if let link = item.links.first { open(link) }
    }

    static func open(_ link: Link) {
        if let url = URL(string: link.url) { NSWorkspace.shared.open(url) }
    }

    /// The item becomes the active one of its planet.
    static func activate(_ item: Item) {
        Journey.shared.activate(item, in: store?.day)
    }

    static func copy(_ item: Item) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.md, forType: .string)
    }

    /// Back to the item's live agent, else a new agent in its worktree, else in the fallback one.
    static func jump(_ item: Item) {
        activate(item)
        perform {
            let config = Config.load()
            if let (worktree, terminal) = try Orca.agent(for: item) {
                if let terminal { try Orca.focus(terminal) } else {
                    try Orca.newAgent(prompt: config.fill(config.resumePrompt, item), in: worktree)
                }
            } else {
                try Orca.newAgent(prompt: config.fill(config.startPrompt, item), in: try Orca.fallback())
            }
        }
    }

    /// A message for the live agent of the item's worktree. No live agent: a new one gets it.
    static func message(_ text: String, to item: Item) {
        activate(item)
        perform {
            if let (worktree, terminal) = try Orca.agent(for: item) {
                if let terminal { try Orca.send(text, to: terminal) } else {
                    try Orca.newAgent(prompt: text, in: worktree)
                }
            } else {
                let config = Config.load()
                try Orca.newAgent(prompt: "\(config.fill(config.startPrompt, item))\n\n\(text)", in: try Orca.fallback())
            }
        }
    }

    /// Always a fresh agent, in the item's worktree or the fallback one.
    static func newAgent(_ prompt: String, for item: Item) {
        activate(item)
        perform {
            let worktree = try Orca.agent(for: item)?.0 ?? Orca.fallback()
            try Orca.newAgent(prompt: prompt, in: worktree)
        }
    }

    static func startPrompt(for item: Item) -> String {
        let config = Config.load()
        return config.fill(config.startPrompt, item)
    }

    private static func perform(_ work: @escaping @Sendable () throws -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do { try work() } catch {
                let message = error.localizedDescription
                Task { @MainActor in store?.report(message) }
            }
        }
    }
}
