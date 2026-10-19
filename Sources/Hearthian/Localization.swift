import SwiftUI

enum Language: String, CaseIterable, Identifiable {
    case system, en, es
    var id: String { rawValue }

    var resolved: Language {
        guard self == .system else { return self }
        return Locale.preferredLanguages.first?.hasPrefix("es") == true ? .es : .en
    }
}

/// Every string the app shows. The day's own content comes from today.json as written.
enum L: String {
    case appTitle, focus, queue, parallel, whileWaiting, decisions, notToday
    case openDay, settings, quit, loading, noDay
    case messageAgent, newAgent, send, cancel, openLink, copyLine
    case agentFor, newAgentFor, typeMessage, jumpHelp, messageHelp, newAgentHelp
    case orcaFailed, noWorktree, language, systemLanguage, english, spanish
    case updated, next, map, launchAtLogin, openAtLoginHelp

    private static let table: [L: (en: String, es: String)] = [
        .appTitle: ("Today", "Parte del día"),
        .focus: ("THE ONE THING", "LA UNA"),
        .queue: ("Queue", "Cola"),
        .parallel: ("Running in parallel", "En paralelo"),
        .whileWaiting: ("While you wait", "Mientras esperas"),
        .decisions: ("Decisions", "Decisiones"),
        .notToday: ("Not today", "Hoy no"),
        .openDay: ("Open day", "Abrir parte"),
        .settings: ("Settings…", "Ajustes…"),
        .quit: ("Quit", "Salir"),
        .loading: ("Loading…", "Cargando…"),
        .noDay: ("No plan for today yet. Waiting for today.json in", "Todavía no hay parte. Esperando today.json en"),
        .messageAgent: ("Message its agent", "Mensaje a su agente"),
        .newAgent: ("New agent", "Agente nuevo"),
        .send: ("Send", "Enviar"),
        .cancel: ("Cancel", "Cancelar"),
        .openLink: ("Open", "Abrir"),
        .copyLine: ("Copy line", "Copiar línea"),
        .agentFor: ("To the agent of", "Al agente de"),
        .newAgentFor: ("New agent for", "Agente nuevo para"),
        .typeMessage: ("Write the message… ⌘↩ to send", "Escribe el mensaje… ⌘↩ para enviar"),
        .jumpHelp: ("Go to its agent in Orca", "Ir a su agente en Orca"),
        .messageHelp: ("Message its live agent", "Mensaje a su agente activo"),
        .newAgentHelp: ("Start a new agent", "Arrancar un agente nuevo"),
        .orcaFailed: ("Orca did not answer", "Orca no ha respondido"),
        .noWorktree: ("No worktree for this item and no fallback worktree in", "No hay worktree para este item ni worktree de reserva en"),
        .language: ("Language", "Idioma"),
        .systemLanguage: ("System", "Sistema"),
        .english: ("English", "Inglés"),
        .spanish: ("Spanish", "Español"),
        .updated: ("Updated", "Actualizado"),
        .next: ("Next", "Ahora"),
        .map: ("Map", "Mapa"),
        .launchAtLogin: ("Open at login", "Abrir al iniciar sesión"),
        .openAtLoginHelp: ("Keeps the menu bar item there from the moment you log in.", "Deja el ítem de la barra de menú puesto desde que inicias sesión."),
    ]

    @MainActor var text: String {
        let pair = Self.table[self] ?? (rawValue, rawValue)
        return AppSettings.shared.language.resolved == .es ? pair.es : pair.en
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    @AppStorage("language") var languageRaw: String = Language.system.rawValue {
        willSet { objectWillChange.send() }
    }
    var language: Language { Language(rawValue: languageRaw) ?? .system }
}
