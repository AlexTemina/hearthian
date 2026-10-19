import SwiftUI

/// One planet: who you are working on, what comes next, the rest of the list, and the way down or up.
struct PlanetView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var store: Store
    @ObservedObject private var journey = Journey.shared
    @ObservedObject private var monitor = AgentMonitor.shared
    let planet: Planet
    var compact = false

    @State private var askingReason = false
    @State private var reason = ""

    var body: some View {
        if let day = store.day {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(day)
                    if let up = waitingAbove(day) { waitingBanner(up) }
                    content(day)
                    moves(day)
                }
                .padding(compact ? 16 : 24)
                .frame(maxWidth: 860, alignment: .leading)
            }
            .onAppear { journey.sync(day) }
        }
    }

    // MARK: Header

    private func header(_ day: Day) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: planet.icon)
                .font(.system(size: compact ? 20 : 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: compact ? 42 : 54, height: compact ? 42 : 54)
                .background(Circle().fill(planet.tone.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(planet.name).font(.system(size: compact ? 20 : 26, weight: .bold, design: .rounded))
                Text(planet.role).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if planet == .brittleHollow || planet == .giantsDeep {
                let list = journey.items(planet, day)
                Text("\(list.filter { !$0.isOpen }.count)/\(list.count)").font(.title3.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ day: Day) -> some View {
        let list = journey.items(planet, day)
        if list.isEmpty {
            Text(L.nothingHere.text).foregroundStyle(.secondary).padding(.vertical, 20)
        } else if planet == .timberHearth {
            frog(day)
        } else {
            if let active = journey.activeItem(planet, day) {
                spotlight(L.activeNow.text, active, strong: true)
                if let next = journey.nextItem(planet, day) { spotlight(L.nextUp.text, next, strong: false) }
            } else {
                Label(L.layerDone.text, systemImage: "checkmark.seal.fill").foregroundStyle(.green).font(.headline)
            }
            if !compact { rail(list, active: journey.activeItem(planet, day)) }
        }
    }

    private func frog(_ day: Day) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let frog = journey.frog(day) {
                spotlight(L.activeNow.text, frog, strong: true)
                if !frog.isOpen, let next = journey.items(.brittleHollow, day).first(where: \.isOpen) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.frogDone.text).font(.headline)
                        Button { journey.promote(next) } label: {
                            Label("\(L.promoteNext.text): \(next.heading)", systemImage: "arrow.up.circle.fill")
                        }
                        .buttonStyle(.borderedProminent).tint(Planet.timberHearth.tone)
                    }
                    .padding(14)
                    .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            if !day.slots.isEmpty {
                HStack(spacing: 8) {
                    ForEach(day.slots) { slot in
                        Label("\(slot.time) \(slot.title)", systemImage: "clock").font(.caption)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
    }

    private func spotlight(_ label: String, _ item: Item, strong: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 10.5, weight: .heavy)).tracking(0.8)
                .foregroundStyle(strong ? planet.tone : .secondary).padding(.horizontal, 10)
            ItemRow(item: item)
        }
        .padding(.vertical, 10).padding(.horizontal, 6)
        .background(strong ? planet.tone.opacity(0.09) : Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(strong ? planet.tone.opacity(0.3) : .clear))
    }

    /// The metro line: one stop per item, filled when done, the active one marked.
    private func rail(_ list: [Item], active: Item?) -> some View {
        Card(title: L.everything.text, trailing: "\(list.filter { !$0.isOpen }.count)/\(list.count)") {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(item.isOpen ? (item.md == active?.md ? planet.tone : Color.clear) : Color.green)
                            .overlay(Circle().stroke(item.isOpen ? (item.md == active?.md ? planet.tone : Color.secondary.opacity(0.4)) : .green, lineWidth: 2))
                            .frame(width: 12, height: 12)
                            .padding(.top, 13)
                        if index < list.count - 1 {
                            Rectangle().fill(item.isOpen ? Color.secondary.opacity(0.2) : Color.green.opacity(0.6))
                                .frame(width: 2).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 22)
                    VStack(alignment: .leading, spacing: 0) {
                        if let badge = kindBadge(item) { badge.padding(.leading, 10).padding(.top, 4) }
                        ItemRow(item: item, showStatus: false)
                    }
                    if item.isOpen && item.md != active?.md {
                        Button { Actions.activate(item) } label: { Image(systemName: "scope") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).help(L.makeActive.text).padding(.top, 10)
                    }
                }
            }
        }
    }

    private func kindBadge(_ item: Item) -> AnyView? {
        switch item.kind {
        case "decision": AnyView(Label(L.kindDecision.text, systemImage: "questionmark.bubble.fill").font(.caption2.weight(.bold)).foregroundStyle(.pink))
        case "auto": AnyView(Label(L.kindAuto.text, systemImage: "cpu").font(.caption2.weight(.bold)).foregroundStyle(.blue))
        default: nil
        }
    }

    // MARK: Moves

    private func waitingAbove(_ day: Day) -> Planet? {
        var p = planet.above
        while let up = p {
            if let item = up == .timberHearth ? journey.frog(day) : journey.activeItem(up, day),
               item.isOpen, monitor.status(for: item)?.state == .needsYou { return up }
            p = up.above
        }
        return nil
    }

    private func waitingBanner(_ up: Planet) -> some View {
        Button { journey.ascend(to: up) } label: {
            HStack {
                Image(systemName: "bell.badge.fill")
                Text("\(L.waitingAbove.text) \(up.name)").font(.callout.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.up.circle.fill")
            }
            .padding(12)
            .foregroundStyle(.white)
            .background(up.tone.gradient, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// Going down needs an agent thinking on this planet's active task; going up is always open.
    private func canDescend(_ day: Day) -> Bool {
        guard let item = planet == .timberHearth ? journey.frog(day) : journey.activeItem(planet, day) else { return true }
        return !item.isOpen || monitor.status(for: item)?.state == .thinking
    }

    @ViewBuilder
    private func moves(_ day: Day) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let up = planet.above {
                    Button { journey.ascend(to: up) } label: {
                        Label("\(L.ascendTo.text) \(up.name)", systemImage: "arrow.up")
                    }
                }
                Spacer()
                if let below = planet.below {
                    Button { journey.descend(from: planet) } label: {
                        Label("\(L.descendTo.text) \(below.name)", systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(.borderedProminent).tint(below.tone)
                    .disabled(!canDescend(day))
                }
            }
            if planet.below != nil && !canDescend(day) {
                HStack {
                    Text(L.descendLocked.text).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(L.descendAnyway.text) { askingReason = true }.buttonStyle(.link).font(.caption)
                }
                if askingReason {
                    HStack {
                        TextField(L.whyDescend.text, text: $reason).textFieldStyle(.roundedBorder)
                        Button(L.send.text) {
                            journey.descend(from: planet, forced: reason)
                            reason = ""; askingReason = false
                        }
                        .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .padding(.top, 6)
    }
}
