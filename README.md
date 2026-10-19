# Parte

A macOS menu bar app for the day's plan. It shows a ranked queue of what to do today, keeps it live as the plan file changes, and jumps to the [Orca](https://onorca.dev) agent working on each item.

Parte does not plan anything itself. Something else writes `~/Library/Application Support/Parte/hoy.json` (in the author's setup, a Claude Code workflow over a notes vault), and Parte reads it every two seconds.

## What it does

- **Menu bar:** `☀️ 4/15`, done over total in today's queue. Click for the day: La Una (the one thing), the fixed slots, the queue with the next item marked, what runs in parallel.
- **Window:** the same day plus decisions, what is out today and the other sections.
- **On each item:** click opens its first link. 🤖 goes to its agent in Orca: the live agent of the item's worktree, or a new one there, or a new one in a fallback worktree.
- **Right click:** send a message to the live agent of the item's worktree, start a fresh agent with an editable prompt, open any of its links, copy the line.

An item finds its worktree by the Linear issue Orca has linked to it, or by a PR number.

## hoy.json

```json
{
  "date": "2026-10-19", "eyebrow": "Lunes 19 de octubre de 2026", "week": "…",
  "la_una": Item, "slots": [{"time": "11:00", "title": "La Una", "text": "…"}],
  "queue": [Item], "parallel": [Item], "decisions": [Item],
  "while_waiting": "…", "not_today": "…",
  "sections": [{"title": "🔴 Needs attention", "items": [Item]}],
  "progress": {"done": 3, "total": 15}
}
```

`Item`: `{"text", "md", "status": "open|done|moved|snoozed|skipped|dropped", "size", "tags": [], "links": [{"title", "url"}], "issue", "pr"}`.

## Config

`~/Library/Application Support/Parte/config.json`, all optional:

```json
{
  "fallbackWorktree": "/path/to/an/orca/worktree",
  "startPrompt": "Start working on {target}: {text}",
  "resumePrompt": "Continue with {target}: {text}",
  "permissionMode": "auto"
}
```

## Build

macOS 14+, Xcode command line tools, Orca in `/Applications`, `claude` on the login shell `PATH`.

```sh
./scripts/bundle.sh
```

Builds `~/Applications/Parte.app`, ad-hoc signed, and launches it.

## License

MIT
