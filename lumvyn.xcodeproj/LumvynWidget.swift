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
    private func entry(for date: Date) -> LumvynWidgetEntry {
        let hour = Calendar.current.component(.hour, from: date)
        let isSyncing = hour % 3 != 0
        let pending = (hour * 7) % 13

        return LumvynWidgetEntry(
            date: date,
            title: "lumvyn",
            subtitle: isSyncing ? "Sync laeuft" : "Bereit fuer Upload",
            pendingCount: pending,
            isSyncing: isSyncing,
            lastSyncText: isSyncing ? "Jetzt" : "Vor 12 Min"
        )
    }

    func placeholder(in context: Context) -> LumvynWidgetEntry {
        LumvynWidgetEntry(
            date: Date(),
            title: "lumvyn",
            subtitle: "Sync laeuft",
            pendingCount: 3,
            isSyncing: true,
            lastSyncText: "Jetzt"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LumvynWidgetEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LumvynWidgetEntry>) -> Void) {
        let now = Date()
        let entry = entry(for: now)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct LumvynWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LumvynWidgetEntry

    private var syncColor: Color {
        entry.isSyncing ? Color(red: 0.06, green: 0.55, blue: 0.97) : Color(red: 0.20, green: 0.70, blue: 0.42)
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumWidget
            case .accessoryRectangular:
                accessoryWidget
            default:
                smallWidget
            }
        }
        .modifier(WidgetSurface())
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(entry.pendingCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("ausstehend")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            progressPill
        }
        .padding(16)
    }

    private var mediumWidget: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                header

                Text(entry.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Letzter Lauf: \(entry.lastSyncText)")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)

                Spacer(minLength: 0)

                progressPill
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Text("\(entry.pendingCount)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Dateien")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 88)
            .padding(.vertical, 10)
            .background(syncColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
    }

    private var accessoryWidget: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                .foregroundStyle(syncColor)
            Text(entry.isSyncing ? "Sync aktiv" : "Bereit")
                .font(.caption.weight(.semibold))
            Spacer()
            Text("\(entry.pendingCount)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(syncColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(syncColor)
            }

            Text(entry.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            if entry.isSyncing {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(syncColor)
            }
        }
    }

    private var progressPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(syncColor)
                .frame(width: 6, height: 6)
            Text(entry.isSyncing ? "Automatisch sichern aktiv" : "Automatisch sichern bereit")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
}

private struct WidgetSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content
                .containerBackground(.ultraThinMaterial, for: .widget)
        } else {
            content
                .background(.ultraThinMaterial)
        }
    }
}

@main
struct LumvynWidget: Widget {
    let kind = "LumvynWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LumvynWidgetProvider()) { entry in
            LumvynWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("lumvyn Widget")
        .description("Zeigt den aktuellen Sync-Status und ausstehende Uploads auf einen Blick.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
