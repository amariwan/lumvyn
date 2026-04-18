import AVKit
import SwiftUI

// Reuse shared platform compatibility helpers from Views/PlatformSupport.swift

struct AssetDetailView: View {
    let asset: RemoteAsset
    let siblings: [RemoteAsset]

    @EnvironmentObject private var galleryStore: GalleryStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int
    @State private var showChrome: Bool = true
    @State private var pendingDelete: Bool = false
    @State private var sharedItem: ShareItem? = nil

    init(asset: RemoteAsset, siblings: [RemoteAsset]) {
        self.asset = asset
        self.siblings = siblings
        let idx = siblings.firstIndex(where: { $0.remotePath == asset.remotePath }) ?? 0
        self._currentIndex = State(initialValue: idx)
    }

    private var currentAsset: RemoteAsset {
        siblings.indices.contains(currentIndex) ? siblings[currentIndex] : asset
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(siblings.indices, id: \.self) { idx in
                    AssetPageView(asset: siblings[idx])
                        .tag(idx)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { showChrome.toggle() }
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            if showChrome {
                VStack {
                    topBar
                    Spacer()
                    bottomBar
                }
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showChrome)
        .toolbar(.hidden, for: .tabBar)
        .alert(
            LocalizedStringKey("gallery.delete.confirm.title"),
            isPresented: $pendingDelete
        ) {
            Button(LocalizedStringKey("Abbrechen"), role: .cancel) {}
            Button(LocalizedStringKey("Löschen"), role: .destructive) {
                Task { await deleteCurrent() }
            }
        } message: {
            Text(LocalizedStringKey("gallery.delete.confirm.message"))
        }
        .sheet(item: $sharedItem) { item in
            ActivityView(activityItems: [item.url])
        }
    }

    private var topBar: some View {
        let asset = currentAsset
        return HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44, alignment: .leading)
            }

            VStack(spacing: 1) {
                Text(asset.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(DateFormatter.localizedString(
                    from: asset.modifiedAt, dateStyle: .medium, timeStyle: .short
                ))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)

            Menu {
                Button {
                    Task { await shareCurrent() }
                } label: {
                    Label(LocalizedStringKey("Teilen"), systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    pendingDelete = true
                } label: {
                    Label(LocalizedStringKey("Löschen"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.55), .clear],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .top)
        )
    }

    private var bottomBar: some View {
        let asset = currentAsset
        return HStack(spacing: 8) {
            Image(systemName: asset.isBackedUp ? "checkmark.icloud.fill" : "xmark.icloud")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(asset.isBackedUp ? .green : .orange)
            Text(asset.isBackedUp
                 ? NSLocalizedString("gallery.asset.backedUp", comment: "")
                 : NSLocalizedString("gallery.asset.notBackedUp", comment: ""))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)

            Spacer()

            Text(metadataLine(for: asset))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [.clear, Color.black.opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func metadataLine(for asset: RemoteAsset) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let size = formatter.string(fromByteCount: asset.size)
        let date = DateFormatter.localizedString(from: asset.modifiedAt, dateStyle: .medium, timeStyle: .short)
        return "\(size) · \(date)"
    }

    private func shareCurrent() async {
        do {
            let url = try await galleryStore.downloadFullResolution(currentAsset)
            sharedItem = ShareItem(url: url)
        } catch {
            galleryStore.error = (error as? GalleryError) ?? .loadFailed(error.localizedDescription)
        }
    }

    private func deleteCurrent() async {
        let asset = currentAsset
        do {
            try await galleryStore.delete(asset)
            dismiss()
        } catch {
            galleryStore.error = (error as? GalleryError) ?? .deleteFailed(error.localizedDescription)
        }
    }
}

struct AssetPageView: View {
    let asset: RemoteAsset
    @EnvironmentObject private var galleryStore: GalleryStore

    @State private var fullImage: PlatformImage? = nil
    @State private var videoURL: URL? = nil
    @State private var loadError: String? = nil
    @State private var thumbnailImage: PlatformImage? = nil

    var body: some View {
        Group {
            switch asset.mediaType {
            case .photo:
                PhotoPageView(thumbnail: thumbnailImage, fullImage: fullImage, errorMessage: loadError)
            case .video:
                VideoPageView(fullURL: videoURL, thumbnail: thumbnailImage, errorMessage: loadError)
            case .unknown:
                Text(asset.displayName)
                    .foregroundStyle(.white)
            }
        }
        .task(id: asset.remotePath) {
            if let data = await galleryStore.thumbnail(for: asset),
               let img = platformImage(from: data) {
                thumbnailImage = img
            }
            switch asset.mediaType {
            case .photo:
                if let data = await galleryStore.fullResolutionData(for: asset),
                   let img = platformImage(from: data),
                   !Task.isCancelled {
                    fullImage = img
                } else if !Task.isCancelled {
                    loadError = NSLocalizedString("gallery.error.connectionFailed", comment: "")
                }
            case .video:
                do {
                    let url = try await galleryStore.downloadFullResolution(asset)
                    if !Task.isCancelled { videoURL = url }
                } catch {
                    loadError = error.localizedDescription
                }
            case .unknown:
                break
            }
        }
        .onDisappear {
            if let url = videoURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

private struct PhotoPageView: View {
    let thumbnail: PlatformImage?
    let fullImage: PlatformImage?
    let errorMessage: String?

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let fullImage {
                    Image(platformImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { val in
                                    scale = min(max(lastScale * val, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                scale = scale > 1.0 ? 1.0 : 2.0
                                lastScale = scale
                            }
                        }
                } else if let thumbnail {
                    ZStack {
                        Image(platformImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .blur(radius: 12)
                            .opacity(0.6)
                        ProgressView().tint(.white)
                    }
                } else if let errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct VideoPageView: View {
    let fullURL: URL?
    let thumbnail: PlatformImage?
    let errorMessage: String?

    var body: some View {
        ZStack {
            if let fullURL {
                VideoPlayer(player: AVPlayer(url: fullURL))
            } else if let thumbnail {
                ZStack {
                    Image(platformImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .opacity(0.5)
                    ProgressView().tint(.white)
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.white)
                    .padding()
            } else {
                ProgressView().tint(.white)
            }
        }
    }
}
