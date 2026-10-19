import Foundation
import SwiftUI

/// Reads ~/Library/Application Support/Hearthian/hoy.json and keeps it current: the vault's renderer
/// rewrites that file on every Daily refresh, and the app picks it up within two seconds.
enum Paths {
    static let folder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Hearthian")
    static let dayFile = folder.appendingPathComponent("today.json")
    static let pageFile = folder.appendingPathComponent("today.html")
}

@MainActor
final class Store: ObservableObject {
    static let dayFile = Paths.dayFile
    static let pageFile = Paths.pageFile

    @Published private(set) var day: Day?
    @Published private(set) var error: String?
    @Published private(set) var updated: Date?
    @Published var failure: String?

    private var lastModified: Date?
    private var timer: Timer?

    init() {
        load()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.load() }
        }
    }

    func load() {
        let attributes = try? FileManager.default.attributesOfItem(atPath: Self.dayFile.path)
        let modified = attributes?[.modificationDate] as? Date
        guard modified != lastModified || day == nil else { return }
        lastModified = modified
        do {
            let data = try Data(contentsOf: Self.dayFile)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            day = try decoder.decode(Day.self, from: data)
            error = nil
            updated = modified
        } catch {
            self.error = Self.dayFile.path
        }
    }

    func report(_ message: String) {
        failure = message
        Task {
            try? await Task.sleep(for: .seconds(8))
            if failure == message { failure = nil }
        }
    }

    var menuTitle: String {
        guard let day else { return "☀️" }
        return "☀️ \(day.progress.done)/\(day.progress.total)"
    }
}
