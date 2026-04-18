import SwiftUI

// MARK: - UploadRowView

struct UploadRowView: View {
    let item: UploadItem
    let retryAction: () -> Void
    @EnvironmentObject private var queueManager: UploadQueueManager
    @State private var isShowingPreview: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Header row ──────────────────────────────────────
            HStack(spacing: 12) {
                MediaThumbnail(mediaType: item.mediaType, status: item.status)
                    .onTapGesture { isShowingPreview = true }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(item.mediaType.displayName)

                        if !item.subtypes.isEmpty {
                            Text("·").foregroundStyle(.tertiary)
                            Text(item.subtypes.joined(separator: ", "))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                StatusChip(status: item.status)
            }

            // ── Progress bar ────────────────────────────────────
            ProgressView(value: item.progress)
                .progressViewStyle(.linear)
                .tint(item.status.color)
                .animation(.linear(duration: 0.35), value: item.progress)

            // ── Progress meta (Prozent + ETA) ─────────────────────
            ProgressMeta(
                progress: item.progress,
                fileSize: item.fileSize,
                uploadRate: queueManager.uploadRateBytesPerSecond,
                status: item.status
            )

            // ── Meta labels (Kompakter) ─────────────────────────
            if (item.albumName != nil && item.albumName?.isEmpty == false) || item.locationName != nil {
                HStack(spacing: 12) {
                    if let albumName = item.albumName, !albumName.isEmpty {
                        Label(albumName, systemImage: "square.stack")
                    }
                    if let locationName = item.locationName {
                        Label(locationName, systemImage: "location")
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }

            // ── Error Banner + Retry Button (Redesigned) ───────
            if let error = item.lastError, item.status == .failed {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)

                    Text(error)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                        .lineLimit(2)

                    Spacer()

                    Button(action: retryAction) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        // ── Swipe actions (iOS) & Preview sheet ─────────────────
        #if os(iOS)
        .swipeActions(edge: .trailing) {
            Button {
                Task { await queueManager.retry(item: item) }
            } label: {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
            }
            .tint(.blue)

            Button(role: .destructive) {
                queueManager.remove(item: item)
            } label: { Label("Löschen", systemImage: "trash") }
        }
        #endif
        .sheet(isPresented: $isShowingPreview) {
            UploadPreviewSheet(item: item)
        }

        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: item.status)
    }
}
