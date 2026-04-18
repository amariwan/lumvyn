import SwiftUI

// MARK: - QueueStats

private struct QueueStats: Equatable {
    var pending:       Int    = 0
    var uploading:     Int    = 0
    var done:          Int    = 0
    var failed:        Int    = 0
    var totalProgress: Double = 0.0
}

// MARK: - OverviewView

struct OverviewView: View {
    @EnvironmentObject private var queueManager:  UploadQueueManager
    @EnvironmentObject private var settingsStore: SettingsStore

    private var stats: QueueStats {
        queueManager.items.reduce(into: QueueStats()) { acc, item in
            switch item.status {
            case .pending:   acc.pending   += 1
            case .uploading: acc.uploading += 1
            case .done:      acc.done      += 1
            case .failed:    acc.failed    += 1
            }
            acc.totalProgress += item.progress
        }
    }

    private var overallProgress: Double {
        queueManager.items.isEmpty
            ? 0.0
            : stats.totalProgress / Double(queueManager.items.count)
    }

    var body: some View {
        List {
            // ── Dashboard Card ─────────────────────────────────────
            Section {
                DashboardCard(
                    itemCount:    queueManager.items.count,
                    progress:     overallProgress,
                    isProcessing: queueManager.isProcessing,
                    uploadRate:   queueManager.uploadRateBytesPerSecond,
                    stats:        stats
                )
                .listRowInsets(.init(top: 16, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                QuickActionsCard(
                    isProcessing: queueManager.isProcessing,
                    canStart: settingsStore.isConfigured,
                    hasFailedItems: stats.failed > 0,
                    hasDoneItems: stats.done > 0,
                    onPrimaryTap: {
                        if queueManager.isProcessing {
                            queueManager.stopProcessing()
                        } else {
                            Task { await queueManager.scanLibraryAndImport() }
                        }
                    },
                    onRetryTap: {
                        Task { await queueManager.retryAll() }
                    },
                    onClearTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            queueManager.clearCompleted()
                        }
                    }
                )
                .listRowInsets(.init(top: 6, leading: 16, bottom: 10, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // ── Configuration Warning ──────────────────────────────
            if !settingsStore.isConfigured {
                Section {
                    ConfigWarningBanner()
                        .listRowInsets(.init(top: 0, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            // ── File List ──────────────────────────────────────────
            Section {
                if queueManager.items.isEmpty {
                    EmptyQueueView()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(queueManager.items) { item in
                        UploadRowView(item: item) {
                            Task { await queueManager.retry(item: item) }
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .padding(.vertical, 3)
                        )
                        .listRowSeparator(.hidden)
                        .transition(.asymmetric(
                            insertion: .push(from: .trailing).combined(with: .opacity),
                            removal:   .push(from: .leading).combined(with: .opacity)
                        ))
                    }
                    .onDelete { offsets in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            queueManager.remove(atOffsets: offsets)
                        }
                    }
                }
            } header: {
                if !queueManager.items.isEmpty {
                    FilesSectionHeader(count: queueManager.items.count)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: queueManager.items.count)
        .animation(.spring(response: 0.40, dampingFraction: 0.85), value: settingsStore.isConfigured)
        .navigationTitle("Übersicht")
        .navigationBarTitleDisplayMode(.large)
        #if os(iOS)
        .toolbar { overviewToolbar() }
        #endif
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func overviewToolbar() -> some ToolbarContent {
        if stats.done > 0 {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        queueManager.clearCompleted()
                    }
                } label: {
                    Label("Erledigte löschen", systemImage: "checkmark.circle.badge.xmark")
                }
                .tint(.secondary)
                .accessibilityLabel("Abgeschlossene Uploads löschen")
            }
        }

        if stats.failed > 0 {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await queueManager.retryAll() }
                } label: {
                    Label("Alle erneut versuchen", systemImage: "arrow.clockwise")
                }
                .disabled(!settingsStore.isConfigured)
                .accessibilityLabel("Alle fehlgeschlagenen Uploads erneut versuchen")
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                if queueManager.isProcessing {
                    queueManager.stopProcessing()
                } else {
                    Task { await queueManager.scanLibraryAndImport() }
                }
            } label: {
                Label(
                    queueManager.isProcessing ? "Import stoppen" : "Import starten",
                    systemImage: queueManager.isProcessing ? "stop.fill" : "play.fill"
                )
            }
            .symbolEffect(.bounce, value: queueManager.isProcessing)
            .disabled(!settingsStore.isConfigured && !queueManager.isProcessing)
            .accessibilityLabel(queueManager.isProcessing ? "Import stoppen" : "Import starten")
        }
    }
}

// MARK: - Quick Actions Card

private struct QuickActionsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let isProcessing: Bool
    let canStart: Bool
    let hasFailedItems: Bool
    let hasDoneItems: Bool
    let onPrimaryTap: () -> Void
    let onRetryTap: () -> Void
    let onClearTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schnellaktionen")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                Button(action: onPrimaryTap) {
                    Label(
                        isProcessing ? "Stoppen" : "Starten",
                        systemImage: isProcessing ? "stop.fill" : "play.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.10, green: 0.56, blue: 0.96))
                .disabled(!canStart && !isProcessing)

                if hasFailedItems {
                    Button(action: onRetryTap) {
                        Label("Erneut", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.bordered)
                }

                if hasDoneItems {
                    Button(action: onClearTap) {
                        Label("Leeren", systemImage: "checkmark.circle.badge.xmark")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.platformSecondaryBackground.opacity(0.14), Color.platformSystemBackground.opacity(0.06)]
                    : [Color.white.opacity(0.65), Color.white.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.platformSeparator.opacity(colorScheme == .dark ? 0.22 : 0.18), lineWidth: 0.8)
        )
    }
}

// MARK: - Files Section Header

private struct FilesSectionHeader: View {
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Dateien")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
            Spacer()
            Text("\(count)")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(.tertiary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Dashboard Card

private struct DashboardCard: View {
    let itemCount:    Int
    let progress:     Double
    let isProcessing: Bool
    let uploadRate:   Double
    let stats:        QueueStats

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // ── Counter + Progress Ring ────────────────────────────
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Warteschlange")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                        .textCase(.uppercase)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(itemCount)")
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(countsDown: false))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: itemCount)
                        Text("Elemente")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .offset(y: -4)
                    }

                    if isProcessing {
                        LiveUploadBadge(uploadRate: uploadRate)
                            .transition(.push(from: .bottom).combined(with: .opacity))
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(itemCount) Elemente in der Warteschlange")
                .accessibilityValue(isProcessing ? "Wird hochgeladen" : "Bereit")

                Spacer(minLength: 0)

                ProgressRing(progress: progress)
                    .accessibilityLabel("Gesamtfortschritt")
                    .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
            }
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.platformSeparator.opacity(0.45))
                .frame(height: 0.5)
                .padding(.horizontal, -20)

            // ── Status Tiles ───────────────────────────────────────
            StatusTileGrid(
                pending:   stats.pending,
                uploading: stats.uploading,
                done:      stats.done,
                failed:    stats.failed
            )
            .padding(.top, 14)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.platformSeparator.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Live Upload Badge

private struct LiveUploadBadge: View {
    let uploadRate: Double

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(.blue)
                .frame(width: 7, height: 7)
                .scaleEffect(pulse ? 1.5 : 1.0)
                .opacity(pulse ? 0.4 : 1.0)
                .animation(
                    .easeInOut(duration: 0.75).repeatForever(autoreverses: true),
                    value: pulse
                )

            Text("Lädt hoch")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            if uploadRate > 0 {
                Text("·")
                    .foregroundStyle(.quaternary)

                HStack(spacing: 1) {
                    Text(Int64(uploadRate), format: .byteCount(style: .binary))
                        .font(.caption.weight(.semibold).monospacedDigit())
                    Text("/s")
                        .font(.caption)
                }
                .foregroundStyle(.primary.opacity(0.65))
            }
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Progress Ring

private struct ProgressRing: View {
    let progress: Double

    private let size:      CGFloat = 74
    private let lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.platformSystemFill, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: .accentColor.opacity(0.35), radius: 5, x: 0, y: 2)
                .animation(.spring(response: 0.8, dampingFraction: 0.85), value: progress)

            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.25), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status Tile Grid

private struct StatusTileGrid: View {
    let pending:   Int
    let uploading: Int
    let done:      Int
    let failed:    Int

    var body: some View {
        HStack(spacing: 8) {
            StatusTile(value: pending,   title: "Ausstehend", image: "clock.fill",                   color: .orange, delay: 0.00)
            StatusTile(value: uploading, title: "Aktiv",      image: "arrow.up.circle.fill",         color: .blue,   delay: 0.06)
            StatusTile(value: done,      title: "Fertig",     image: "checkmark.circle.fill",        color: .green,  delay: 0.12)
            StatusTile(value: failed,    title: "Fehler",     image: "exclamationmark.circle.fill",  color: .red,    delay: 0.18)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct StatusTile: View {
    let value: Int
    let title: LocalizedStringKey
    let image: String
    let color: Color
    let delay: Double

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: image)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)

            Text("\(value)")
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: value)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.18), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.85)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(delay)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(value)"))
    }
}

// MARK: - Config Warning Banner

private struct ConfigWarningBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Konfiguration fehlt")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("SMB-Server und Anmeldedaten einrichten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.22), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Konfigurationswarnung: SMB-Server und Anmeldedaten sind nicht eingerichtet.")
        .accessibilityHint("Einstellungen öffnen, um den SMB-Server zu konfigurieren.")
    }
}

// MARK: - Empty Queue View

private struct EmptyQueueView: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(appeared ? 1 : 0.65)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 5) {
                Text("Alles erledigt")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Keine Mediendateien in der Warteschlange.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.70).delay(0.1)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warteschlange leer. Keine Mediendateien vorhanden.")
    }
}
