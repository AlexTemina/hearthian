import Foundation

struct Link: Codable, Hashable {
    let title: String
    let url: String
}

struct Item: Codable, Hashable, Identifiable {
    var id: String { md }
    let text: String
    let md: String
    let status: String
    let size: String?
    let tags: [String]
    let links: [Link]
    let issue: String?
    let pr: Int?

    var isOpen: Bool { status == "open" }

    var icon: String {
        switch status {
        case "done": "✅"
        case "moved": "↪️"
        case "snoozed": "💤"
        case "skipped": "⏭️"
        case "dropped": "❌"
        default: "○"
        }
    }

    /// What identifies the work in Orca: a Linear issue, else a PR number.
    var target: String? { issue ?? pr.map { "#\($0)" } }
}

struct Slot: Codable, Hashable, Identifiable {
    var id: String { time + title }
    let time: String
    let title: String
    let text: String
}

struct Section: Codable, Identifiable {
    var id: String { title }
    let title: String
    let items: [Item]
}

struct Progress: Codable {
    let done: Int
    let total: Int
}

struct Day: Codable {
    let date: String
    let eyebrow: String
    let week: String?
    let laUna: Item?
    let slots: [Slot]
    let queue: [Item]
    let parallel: [Item]
    let decisions: [Item]
    let whileWaiting: String?
    let notToday: String?
    let sections: [Section]
    let progress: Progress

    var next: Item? { queue.first(where: \.isOpen) }
}
