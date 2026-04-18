import SwiftUI

struct UploadPreviewSheet: View {
    let item: UploadItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: item.mediaType.isVideo ? "film" : "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 260)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.fileName).font(.headline)
                    Text(item.mediaType.displayName).font(.subheadline).foregroundStyle(.secondary)
                    Text(item.createdAt, style: .date).font(.caption)
                    if let size = item.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding()

                Spacer()
            }
            .padding()
            .navigationTitle("Vorschau")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }
}
