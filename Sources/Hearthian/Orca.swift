import AppKit
import Foundation

/// Everything that touches Orca goes through its CLI, the same way Orca Summon does.
enum Orca {
    static let cli = "/Applications/Orca.app/Contents/Resources/bin/orca"

    struct Worktree: Decodable {
        let id: String
        let path: String
        let displayName: String
        let isMainWorktree: Bool
        let isArchived: Bool
        let linkedLinearIssue: String?
        let linkedPR: Int?
        let isUnread: Bool?
        let workspaceStatus: String?
        let comment: String?
    }

    struct Terminal: Decodable {
        let handle: String
        let worktreeId: String
        let connected: Bool
        let title: String?
        let agentIdentity: String?
        let lastOutputAt: Double?
    }

    enum Failure: LocalizedError {
        case command(String)
        case noWorktree(String)
        var errorDescription: String? {
            switch self {
            case .command(let message): message
            case .noWorktree(let target): "No worktree for \(target), and no fallbackWorktree in \(Config.file.path)"
            }
        }
    }

    @discardableResult
    static func run(_ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cli)
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw Failure.command(message.isEmpty ? "orca \(arguments.first ?? "") failed" : message)
        }
        return data
    }

    private struct Envelope<T: Decodable>: Decodable { let result: T }
    private struct Worktrees: Decodable { let worktrees: [Worktree] }
    private struct Terminals: Decodable { let terminals: [Terminal] }

    static func worktrees() throws -> [Worktree] {
        let data = try run(["worktree", "list", "--json"])
        return try JSONDecoder().decode(Envelope<Worktrees>.self, from: data).result.worktrees.filter { !$0.isArchived }
    }

    static func terminals() throws -> [Terminal] {
        let data = try run(["terminal", "list", "--json"])
        return try JSONDecoder().decode(Envelope<Terminals>.self, from: data).result.terminals
    }

    static func worktree(for item: Item, in worktrees: [Worktree]) -> Worktree? {
        if let issue = item.issue?.lowercased() {
            if let w = worktrees.first(where: { $0.linkedLinearIssue?.lowercased() == issue }) { return w }
            if let w = worktrees.first(where: { $0.displayName.lowercased().contains(issue) }) { return w }
        }
        if let pr = item.pr {
            if let w = worktrees.first(where: { $0.linkedPR == pr }) { return w }
            if let w = worktrees.first(where: { $0.displayName.contains("\(pr)") }) { return w }
        }
        return nil
    }

    /// The live agent of the item's worktree, if there is one.
    static func agent(for item: Item) throws -> (Worktree, Terminal?)? {
        let all = try worktrees()
        guard let worktree = worktree(for: item, in: all) else { return nil }
        let live = try terminals().filter { $0.worktreeId == worktree.id && $0.connected }
        return (worktree, live.first(where: { ($0.title ?? "").hasPrefix("✳") }) ?? live.first)
    }

    static func focus(_ terminal: Terminal) throws {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Orca.app"))
        try run(["terminal", "switch", "--terminal", terminal.handle, "--json"])
    }

    static func send(_ text: String, to terminal: Terminal) throws {
        try focus(terminal)
        try run(["terminal", "send", "--terminal", terminal.handle, "--text", text, "--enter", "--json"])
    }

    static func newAgent(prompt: String, in worktree: Worktree) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hearthian-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("prompt.txt")
        try prompt.write(to: file, atomically: true, encoding: .utf8)
        let mode = Config.load().permissionMode
        let command = "claude --permission-mode \(mode) \"$(cat '\(file.path)')\"; rm -rf '\(dir.path)'"
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Orca.app"))
        try run(["terminal", "create", "--worktree", "id:\(worktree.id)", "--command", command, "--focus", "--json"])
    }

    /// Where an item without a worktree of its own gets started.
    static func fallback() throws -> Worktree {
        let path = Config.load().fallbackWorktree
        guard let path, let w = try worktrees().first(where: { $0.path == path }) else {
            throw Failure.noWorktree("this item")
        }
        return w
    }
}

/// ~/Library/Application Support/Hearthian/config.json. Nothing personal lives in the code.
struct Config: Codable {
    var fallbackWorktree: String?
    var startPrompt: String = "Start working on {target}: {text}"
    var resumePrompt: String = "Continue with {target}: {text}"
    var permissionMode: String = "auto"

    static let file = Paths.folder.appendingPathComponent("config.json")

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fallbackWorktree = try c.decodeIfPresent(String.self, forKey: .fallbackWorktree)
        startPrompt = try c.decodeIfPresent(String.self, forKey: .startPrompt) ?? startPrompt
        resumePrompt = try c.decodeIfPresent(String.self, forKey: .resumePrompt) ?? resumePrompt
        permissionMode = try c.decodeIfPresent(String.self, forKey: .permissionMode) ?? permissionMode
    }

    static func load() -> Config {
        guard let data = try? Data(contentsOf: file),
              let config = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        return config
    }

    func fill(_ template: String, _ item: Item) -> String {
        template.replacingOccurrences(of: "{target}", with: item.target ?? "")
            .replacingOccurrences(of: "{text}", with: item.text)
    }
}
