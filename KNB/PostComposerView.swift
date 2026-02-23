//
//  PostComposerView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI
import PhotosUI
import UIKit

struct PostComposerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?

    let postToEdit: SocialPost?

    @State private var postContent = ""
    @State private var isPosting = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var mediaUploads: [SocialPostMediaUpload] = []
    @State private var isProcessingMedia = false
    @State private var showCameraPicker = false
    @State private var pendingCameraImage: UIImage?
    @State private var mediaErrorMessage: String?
    @FocusState private var isFocused: Bool

    private let maxCharacters = 140
    private let maxAttachments = 4

    init(firestoreManager: FirestoreManager, currentUser: Binding<User?>, postToEdit: SocialPost? = nil) {
        self.firestoreManager = firestoreManager
        self._currentUser = currentUser
        self.postToEdit = postToEdit
    }

    private var characterCount: Int {
        postContent.count
    }

    private var remainingCharacters: Int {
        maxCharacters - characterCount
    }

    private var trimmedContent: String {
        postContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEditMode: Bool {
        postToEdit != nil
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var canPost: Bool {
        let hasText = !trimmedContent.isEmpty
        let hasMedia: Bool = isEditMode ? (postToEdit?.hasMedia ?? false) : !mediaUploads.isEmpty

        return (hasText || hasMedia)
            && characterCount <= maxCharacters
            && !isPosting
            && !isProcessingMedia
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.88, green: 0.93, blue: 0.98),
                                        Color(red: 0.90, green: 0.94, blue: 0.99)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.25, green: 0.5, blue: 0.92),
                                        Color(red: 0.3, green: 0.55, blue: 0.96)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ZStack(alignment: .topLeading) {
                            if postContent.isEmpty {
                                Text("Write a message (optional if adding media)")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 16, weight: .regular))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $postContent)
                                .font(.system(size: 17))
                                .focused($isFocused)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 86, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .background(Color.clear)

                        if isEditMode {
                            if let post = postToEdit, !post.mediaItems.isEmpty {
                                SocialPostMediaGalleryView(mediaItems: post.mediaItems, maxHeight: 360)
                                    .padding(.top, 2)

                                Text("Media cannot be changed after posting.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            if !selectedImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 110, height: 110)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color(.systemGray5), lineWidth: 1)
                                                    )

                                                Button {
                                                    removeAttachment(at: index)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 20, weight: .bold))
                                                        .foregroundStyle(.white, .black.opacity(0.65))
                                                        .padding(4)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }

                                Text("\(mediaUploads.count)/\(maxAttachments) attachments")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 14) {
                                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: maxAttachments, matching: .images) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "photo.on.rectangle")
                                        Text("Library")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(
                                        mediaUploads.count < maxAttachments
                                        ? Color(red: 0.25, green: 0.5, blue: 0.92)
                                        : Color.secondary
                                    )
                                }
                                .disabled(mediaUploads.count >= maxAttachments)

                                Button {
                                    showCameraPicker = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "camera")
                                        Text("Camera")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                }
                                .disabled(!cameraAvailable || mediaUploads.count >= maxAttachments)
                                .foregroundStyle((cameraAvailable && mediaUploads.count < maxAttachments) ? Color(red: 0.25, green: 0.5, blue: 0.92) : .secondary)

                                if isProcessingMedia {
                                    HStack(spacing: 6) {
                                        ProgressView().scaleEffect(0.75)
                                        Text("Processing")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                        }

                        HStack {
                            Spacer()

                            Text("\(characterCount)/\(maxCharacters)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    remainingCharacters < 20 ?
                                    (remainingCharacters < 0 ? .red : .orange) :
                                    .secondary
                                )

                            Button(action: handlePost) {
                                HStack(spacing: 6) {
                                    if isPosting {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    } else {
                                        Text(isEditMode ? "Save" : "Post")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    canPost ?
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.25, green: 0.5, blue: 0.92),
                                            Color(red: 0.3, green: 0.55, blue: 0.96)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(
                                        colors: [.gray.opacity(0.5), .gray.opacity(0.4)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(18)
                            }
                            .disabled(!canPost)
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle(isEditMode ? "Edit Post" : "New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                if let post = postToEdit {
                    postContent = post.content
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await processSelectedPhotoItems(newItems)
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                CameraImagePicker(image: $pendingCameraImage)
                    .ignoresSafeArea()
            }
            .onChange(of: pendingCameraImage) { _, newImage in
                guard let captured = newImage else { return }
                Task {
                    await addCapturedImage(captured)
                    await MainActor.run {
                        pendingCameraImage = nil
                    }
                }
            }
            .alert(
                "Media Upload",
                isPresented: Binding(
                    get: { mediaErrorMessage != nil },
                    set: { if !$0 { mediaErrorMessage = nil } }
                ),
                actions: {
                    Button("OK", role: .cancel) { }
                },
                message: {
                    Text(mediaErrorMessage ?? "")
                }
            )
        }
    }

    private func handlePost() {
        guard let user = currentUser else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isPosting = true

        Task {
            let success: Bool
            if let post = postToEdit {
                success = await firestoreManager.updateSocialPost(
                    postId: post.id,
                    content: postContent
                )
            } else {
                success = await firestoreManager.createSocialPost(
                    content: postContent,
                    author: user,
                    mediaUploads: mediaUploads
                )
            }

            await MainActor.run {
                isPosting = false
                if success {
                    dismiss()
                }
            }
        }
    }

    private func removeAttachment(at index: Int) {
        guard index >= 0, index < selectedImages.count, index < mediaUploads.count else { return }
        selectedImages.remove(at: index)
        mediaUploads.remove(at: index)
    }

    private func addCapturedImage(_ image: UIImage) async {
        await MainActor.run {
            mediaErrorMessage = nil
        }

        guard mediaUploads.count < maxAttachments else {
            await MainActor.run {
                mediaErrorMessage = "You can attach up to \(maxAttachments) images."
            }
            return
        }

        await MainActor.run {
            isProcessingMedia = true
        }

        do {
            let prepared = try SocialImageCompressor.prepareUploadWithPreview(from: image)

            await MainActor.run {
                selectedImages.append(prepared.previewImage)
                mediaUploads.append(prepared.upload)
                isProcessingMedia = false
            }
        } catch {
            await MainActor.run {
                isProcessingMedia = false
                mediaErrorMessage = error.localizedDescription
            }
        }
    }

    private func processSelectedPhotoItems(_ items: [PhotosPickerItem]) async {
        await MainActor.run {
            isProcessingMedia = true
            mediaErrorMessage = nil
        }

        let availableSlots = max(0, maxAttachments - mediaUploads.count)
        guard availableSlots > 0 else {
            await MainActor.run {
                isProcessingMedia = false
                mediaErrorMessage = "You can attach up to \(maxAttachments) images."
                selectedPhotoItems = []
            }
            return
        }

        let itemsToProcess = Array(items.prefix(availableSlots))
        var preparedItems: [SocialPreparedUpload] = []
        preparedItems.reserveCapacity(itemsToProcess.count)

        var failureCount = 0
        var lastFailureMessage: String?

        for item in itemsToProcess {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw SocialMediaCompressionError.invalidImageData
                }

                let prepared = try SocialImageCompressor.prepareUploadWithPreview(from: image)
                preparedItems.append(prepared)
            } catch {
                failureCount += 1
                lastFailureMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            selectedImages.append(contentsOf: preparedItems.map(\.previewImage))
            mediaUploads.append(contentsOf: preparedItems.map(\.upload))
            selectedPhotoItems = []
            isProcessingMedia = false

            if items.count > availableSlots {
                mediaErrorMessage = "Only \(maxAttachments) images can be attached per post."
            } else if failureCount > 0 {
                if let lastFailureMessage {
                    mediaErrorMessage = "Some images were skipped. \(lastFailureMessage)"
                } else {
                    mediaErrorMessage = "Some images were skipped during processing."
                }
            }
        }
    }
}

#Preview {
    PostComposerView(
        firestoreManager: FirestoreManager(),
        currentUser: .constant(User(name: "John Doe", email: "john@example.com", totalPledged: 0))
    )
}
