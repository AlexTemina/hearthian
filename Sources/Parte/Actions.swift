import AppKit
import Foundation

/// What a row can do. Every action runs off the main thread and reports failures in an alert.
enum Actions {
    static func open(_ item: Item) {
        guard let link = item.links.first, let url = URL(string: link.url) else { return }
        NSWorkspace.shared.open(url)
    }

    static func open(_ link: Link) {
        if let url = URL(string: link.url) { NSWorkspace.shared.open(url) }
    }

    /// 🤖: back to the item's live agent, or a new one in its worktree, or in the fallback worktree.
    static func jump(_ item: Item) {
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

    /// Right click: a message for the live agent of the item's worktree.
    @MainActor static func message(_ item: Item) {
        guard let text = ask("Mensaje al agente de \(item.target ?? "este item")", item.text) else { return }
        perform {
            guard let (worktree, terminal) = try Orca.agent(for: item) else {
                let config = Config.load()
                try Orca.newAgent(prompt: "\(config.fill(config.startPrompt, item))\n\n\(text)", in: try Orca.fallback())
                return
            }
            if let terminal { try Orca.send(text, to: terminal) } else {
                try Orca.newAgent(prompt: text, in: worktree)
            }
        }
    }

    /// Right click: always a fresh agent, in the item's worktree or the fallback one.
    @MainActor static func newAgent(_ item: Item) {
        let config = Config.load()
        guard let text = ask("Agente nuevo para \(item.target ?? "este item")", item.text,
                             initial: config.fill(config.startPrompt, item)) else { return }
        perform {
            let worktree = try Orca.agent(for: item)?.0 ?? Orca.fallback()
            try Orca.newAgent(prompt: text, in: worktree)
        }
    }

    static func copy(_ item: Item) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.md, forType: .string)
    }

    private static func perform(_ work: @escaping () throws -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do { try work() } catch {
                DispatchQueue.main.async { alert(error.localizedDescription) }
            }
        }
    }

    @MainActor
    private static func ask(_ title: String, _ detail: String, initial: String = "") -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        let field = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 110))
        field.string = initial
        field.font = .systemFont(ofSize: 13)
        field.isRichText = false
        let scroll = NSScrollView(frame: field.frame)
        scroll.documentView = field
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        alert.accessoryView = scroll
        alert.addButton(withTitle: "Enviar")
        alert.addButton(withTitle: "Cancelar")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let text = field.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    @MainActor
    private static func alert(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Orca no ha respondido"
        alert.informativeText = message
        alert.runModal()
    }
}
