import WidgetKit
import SwiftUI

struct LumvynWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let pendingCount: Int
    let isSyncing: Bool
    let lastSyncText: String
}

struct LumvynWidgetProvider: TimelineProvider {
    private func entryFromDefaults(_ date: Date) -> LumvynWidgetEntry {
        let ud = UserDefaults(suiteName: WidgetShared.appGroup)
        let pending = ud?.integer(forKey: WidgetShared.keyPending) ?? 0
        let isSyncing = ud?.bool(forKey: WidgetShared.keyIsSyncing) ?? false
        let last = ud?.string(forKey: WidgetShared.keyLastSyncText) ?? ""

        return LumvynWidgetEntry(
            date: date,
            title: "lumvyn",
            subtitle: isSyncing ? "Sync läuft" : "Bereit",
            pendingCount: pending,
            isSyncing: isSyncing,
            lastSyncText: last.isEmpty ? "-" : last
        )
    }

    func placeholder(in context: Context) -> LumvynWidgetEntry {
        LumvynWidgetEntry(date: Date(), title: "lumvyn", subtitle: "Sync läuft", pendingCount: 2, isSyncing: true, lastSyncText: "Jetzt")
    }

    func getSnapshot(in context: Context, completion: @escaping (LumvynWidgetEntry) -> Void) {
        completion(entryFromDefaults(Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LumvynWidgetEntry>) -> Void) {
        let now = Date()
        let entry = entryFromDefaults(now)
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct LumvynWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LumvynWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
        .padding()
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(entry.title).font(.headline); Spacer(); Image(systemName: entry.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle") }
            Text(entry.subtitle).font(.caption).foregroundStyle(.secondary)
            Text("\(entry.pendingCount) ausstehend").font(.title2).bold()
            Spacer()
            Text("Letzter Lauf: \(entry.lastSyncText)").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text(entry.title).font(.headline)
                Text(entry.subtitle).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.pendingCount)")
                    .font(.system(size: 36, weight: .bold))
            }
            Spacer()
            VStack { Image(systemName: entry.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle"); Text("Dateien") }
        }
    }
}

@main
struct LumvynWidget: Widget {
    let kind = WidgetShared.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LumvynWidgetProvider()) { entry in
            LumvynWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("lumvyn")
        .description("Zeigt den aktuellen Sync-Status und ausstehende Uploads an.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
