import SwiftUI
import PhotosUI
import UIKit
import Combine

enum SocialMediaCompressionError: LocalizedError {
    case invalidImageData
    case failedToEncode
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Could not read the selected image."
        case .failedToEncode:
            return "Could not compress the selected image."
        case .fileTooLarge:
            return "Image is too large even after compression. Please choose a smaller image."
        }
    }
}

struct SocialPreparedUpload {
    let upload: SocialPostMediaUpload
    let previewImage: UIImage
}

enum SocialImageCompressor {
    static let maxDimension: CGFloat = 1600
    static let targetMaxBytes = 1_200_000
    static let hardMaxBytes = 3_000_000

    static func prepareUpload(from image: UIImage) throws -> SocialPostMediaUpload {
        try prepareUploadWithPreview(from: image).upload
    }

    static func prepareUploadWithPreview(from image: UIImage) throws -> SocialPreparedUpload {
        let normalized = normalizeForJPEG(image)

        var quality: CGFloat = 0.82
        guard var jpegData = normalized.jpegData(compressionQuality: quality) else {
            throw SocialMediaCompressionError.failedToEncode
        }

        while jpegData.count > targetMaxBytes && quality > 0.42 {
            quality -= 0.08
            guard let recompressed = normalized.jpegData(compressionQuality: quality) else {
                throw SocialMediaCompressionError.failedToEncode
            }
            jpegData = recompressed
        }

        if jpegData.count > hardMaxBytes {
            throw SocialMediaCompressionError.fileTooLarge
        }

        guard let previewImage = UIImage(data: jpegData) else {
            throw SocialMediaCompressionError.invalidImageData
        }

        let upload = SocialPostMediaUpload(
            data: jpegData,
            width: max(1, Int(previewImage.size.width.rounded())),
            height: max(1, Int(previewImage.size.height.rounded())),
            contentType: "image/jpeg"
        )

        return SocialPreparedUpload(upload: upload, previewImage: previewImage)
    }

    private static func normalizeForJPEG(_ image: UIImage) -> UIImage {
        let resized = resizeIfNeeded(image)
        let targetSize = CGSize(width: max(1, resized.size.width), height: max(1, resized.size.height))

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            resized.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private static func resizeIfNeeded(_ image: UIImage) -> UIImage {
        let originalSize = image.size
        let maxSide = max(originalSize.width, originalSize.height)
        guard maxSide > maxDimension else { return image }

        let ratio = maxDimension / maxSide
        let targetSize = CGSize(
            width: floor(originalSize.width * ratio),
            height: floor(originalSize.height * ratio)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private final class SocialImageMemoryCache {
    static let shared = SocialImageMemoryCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 280
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: max(cost, 1))
    }
}

private enum SocialRemoteImageState {
    case idle
    case loading
    case success(UIImage)
    case failure
}

@MainActor
private final class SocialRemoteImageLoader: ObservableObject {
    @Published private(set) var state: SocialRemoteImageState = .idle

    private var task: Task<Void, Never>?

    func load(url: URL, cacheKey: String) {
        task?.cancel()

        if let cached = SocialImageMemoryCache.shared.image(for: cacheKey) {
            state = .success(cached)
            return
        }

        state = .loading
        task = Task {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 20
                request.cachePolicy = .returnCacheDataElseLoad

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<400).contains(http.statusCode),
                      let image = UIImage(data: data) else {
                    throw URLError(.badServerResponse)
                }

                if Task.isCancelled { return }
                SocialImageMemoryCache.shared.set(image, for: cacheKey)
                state = .success(image)
            } catch {
                if Task.isCancelled { return }
                state = .failure
            }
        }
    }

    func cancel() {
        task?.cancel()
    }

    deinit {
        task?.cancel()
    }
}

private struct SocialPostMediaCell: View {
    let media: SocialPostMedia
    let maxHeight: CGFloat
    var fixedHeight: CGFloat? = nil
    var onTap: (() -> Void)? = nil

    @StateObject private var loader = SocialRemoteImageLoader()

    private var aspectRatio: CGFloat {
        CGFloat(max(media.width, 1)) / CGFloat(max(media.height, 1))
    }

    var body: some View {
        if let url = URL(string: media.downloadURL) {
            mediaBody(url: url)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
                .onAppear {
                    loader.load(url: url, cacheKey: media.storagePath)
                }
                .onChange(of: media.downloadURL) { _, _ in
                    loader.load(url: url, cacheKey: media.storagePath)
                }
                .onDisappear {
                    loader.cancel()
                }
        }
    }

    @ViewBuilder
    private func mediaBody(url: URL) -> some View {
        if let fixedHeight {
            content(url: url)
                .frame(maxWidth: .infinity)
                .frame(height: fixedHeight)
        } else {
            content(url: url)
                .frame(maxWidth: .infinity)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(maxHeight: maxHeight)
        }
    }

    @ViewBuilder
    private func content(url: URL) -> some View {
        switch loader.state {
        case .idle, .loading:
            ZStack {
                Rectangle().fill(Color(.systemGray6))
                ProgressView()
            }

        case .success(let image):
            ZStack {
                Rectangle().fill(Color(.systemGray6))
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

        case .failure:
            ZStack {
                Rectangle().fill(Color(.systemGray6))
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Image unavailable")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        loader.load(url: url, cacheKey: media.storagePath)
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }
}

struct SocialPostMediaView: View {
    let media: SocialPostMedia

    var body: some View {
        SocialPostMediaGalleryView(mediaItems: [media])
    }
}

struct SocialPostMediaGalleryView: View {
    let mediaItems: [SocialPostMedia]
    var maxHeight: CGFloat = 520

    @State private var selectedIndex = 0
    @State private var showFullscreen = false

    private var clampedSelectedIndex: Int {
        guard !mediaItems.isEmpty else { return 0 }
        return min(max(selectedIndex, 0), mediaItems.count - 1)
    }

    var body: some View {
        if !mediaItems.isEmpty {
            VStack(spacing: 8) {
                if mediaItems.count == 1 {
                    SocialPostMediaCell(media: mediaItems[0], maxHeight: maxHeight) {
                        selectedIndex = 0
                        showFullscreen = true
                    }
                } else {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, media in
                            SocialPostMediaCell(
                                media: media,
                                maxHeight: maxHeight,
                                fixedHeight: estimatedHeight(for: media)
                            ) {
                                selectedIndex = index
                                showFullscreen = true
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: estimatedHeight(for: mediaItems[clampedSelectedIndex]))

                    HStack(spacing: 6) {
                        ForEach(mediaItems.indices, id: \.self) { index in
                            Circle()
                                .fill(index == clampedSelectedIndex ? Color.primary : Color.secondary.opacity(0.35))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .onAppear {
                selectedIndex = clampedSelectedIndex
            }
            .onChange(of: mediaItems.count) { _, _ in
                selectedIndex = clampedSelectedIndex
            }
            .fullScreenCover(isPresented: $showFullscreen) {
                SocialMediaFullscreenViewer(
                    mediaItems: mediaItems,
                    initialIndex: clampedSelectedIndex
                )
            }
        }
    }

    private func estimatedHeight(for media: SocialPostMedia) -> CGFloat {
        let width = max(200, UIScreen.main.bounds.width - 92)
        let ratio = CGFloat(max(media.width, 1)) / CGFloat(max(media.height, 1))
        return min(width / max(ratio, 0.01), maxHeight)
    }
}

private struct SocialMediaFullscreenViewer: View {
    let mediaItems: [SocialPostMedia]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int

    init(mediaItems: [SocialPostMedia], initialIndex: Int) {
        self.mediaItems = mediaItems
        _selectedIndex = State(initialValue: min(max(initialIndex, 0), max(mediaItems.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, media in
                    ZoomableSocialRemoteImageView(media: media)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    }

                    Spacer()

                    Text("\(selectedIndex + 1)/\(mediaItems.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.14))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                Spacer()
            }
        }
    }
}

private struct ZoomableSocialRemoteImageView: View {
    let media: SocialPostMedia

    @StateObject private var loader = SocialRemoteImageLoader()
    @State private var baseScale: CGFloat = 1
    @State private var pinchScale: CGFloat = 1

    private var zoomScale: CGFloat {
        min(max(baseScale * pinchScale, 1), 4)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch loader.state {
                case .idle, .loading:
                    ProgressView().tint(.white)

                case .failure:
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("Failed to load image")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                        if let url = URL(string: media.downloadURL) {
                            Button("Retry") {
                                loader.load(url: url, cacheKey: media.storagePath)
                            }
                            .font(.system(size: 14, weight: .semibold))
                        }
                    }

                case .success(let image):
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width)
                            .scaleEffect(zoomScale)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        pinchScale = value
                                    }
                                    .onEnded { _ in
                                        baseScale = zoomScale
                                        pinchScale = 1
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    if zoomScale > 1 {
                                        baseScale = 1
                                        pinchScale = 1
                                    } else {
                                        baseScale = 2
                                        pinchScale = 1
                                    }
                                }
                            }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black)
            .onAppear {
                if let url = URL(string: media.downloadURL) {
                    loader.load(url: url, cacheKey: media.storagePath)
                }
            }
            .onChange(of: media.downloadURL) { _, _ in
                if let url = URL(string: media.downloadURL) {
                    loader.load(url: url, cacheKey: media.storagePath)
                }
            }
        }
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let captured = info[.originalImage] as? UIImage {
                parent.image = captured
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
