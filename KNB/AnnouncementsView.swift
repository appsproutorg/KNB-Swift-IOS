//
//  AnnouncementsView.swift
//  KNB
//
//  Created by AI Assistant
//

import SwiftUI

struct AnnouncementsView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    
    @State private var newMessage: String = ""
    @State private var isPosting = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages list
                    if firestoreManager.announcements.isEmpty {
                        // Empty state
                        ScrollView {
                            VStack(spacing: 28) {
                                Spacer()
                                
                                ZStack {
                                    // Animated glow
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.25),
                                                    .clear
                                                ],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 100
                                            )
                                        )
                                        .frame(width: 180, height: 180)
                                        .blur(radius: 30)
                                    
                                    // Icon
                                    Image(systemName: "megaphone.fill")
                                        .font(.system(size: 80, weight: .light))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.3, green: 0.5, blue: 0.95),
                                                    Color(red: 0.4, green: 0.6, blue: 1.0)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .symbolRenderingMode(.hierarchical)
                                        .shadow(color: Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3), radius: 20, x: 0, y: 10)
                                }
                                .padding(.top, 80)
                                
                                VStack(spacing: 12) {
                                    Text("No Announcements Yet")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    
                                    Text("Be the first to share an update")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(firestoreManager.announcements.indices, id: \.self) { index in
                                        let announcement = firestoreManager.announcements[index]
                                        FluidAnnouncementCard(
                                            announcement: announcement,
                                            currentUserEmail: currentUser?.email,
                                            index: index,
                                            onDelete: {
                                                Task {
                                                    await firestoreManager.deleteAnnouncement(announcementId: announcement.id)
                                                }
                                            }
                                        )
                                        .id(announcement.id)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 20)
                            }
                            .onChange(of: firestoreManager.announcements.count) { _ in
                                // Auto-scroll to bottom on new message
                                if let lastMessage = firestoreManager.announcements.last {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Chat input bar
                    HStack(spacing: 12) {
                        // Text field with icon
                        HStack(spacing: 10) {
                            Image(systemName: "megaphone")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.6))
                            
                            TextField("Share an announcement...", text: $newMessage, axis: .vertical)
                                .lineLimit(1...4)
                                .font(.system(size: 16, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    isInputFocused ?
                                    Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.4) :
                                    Color(.systemGray5),
                                    lineWidth: 1.5
                                )
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInputFocused)
                        .focused($isInputFocused)
                        
                        // Send button
                        Button(action: sendMessage) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.3, green: 0.55, blue: 0.96),
                                                Color(red: 0.4, green: 0.65, blue: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .shadow(
                                        color: Color(red: 0.3, green: 0.55, blue: 0.96).opacity(0.4),
                                        radius: 12,
                                        x: 0,
                                        y: 4
                                    )
                                
                                if isPosting {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .scaleEffect(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.85 : 1.0)
                            .opacity(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        }
                        .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: newMessage.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Color(.systemGroupedBackground)
                            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -4)
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.3, green: 0.55, blue: 0.96),
                                            Color(red: 0.4, green: 0.65, blue: 1.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Announcements")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        
                        if !firestoreManager.announcements.isEmpty {
                            Text("\(firestoreManager.announcements.count) messages")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                firestoreManager.startListeningToAnnouncements()
            }
            .onDisappear {
                firestoreManager.stopListeningToAnnouncements()
            }
        }
    }
    
    private func sendMessage() {
        guard let user = currentUser, !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageToSend = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        newMessage = "" // Clear immediately for better UX
        isPosting = true
        
        Task {
            let success = await firestoreManager.postAnnouncement(
                authorName: user.name,
                authorEmail: user.email,
                message: messageToSend,
                isImportant: false
            )
            
            isPosting = false
            
            if success {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            } else {
                // Restore message if failed
                newMessage = messageToSend
            }
        }
    }
}

// MARK: - Fluid Announcement Card
struct FluidAnnouncementCard: View {
    let announcement: Announcement
    let currentUserEmail: String?
    let index: Int
    var onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    @State private var cardScale: CGFloat = 0.85
    @State private var cardOpacity: Double = 0
    @State private var cardOffset: CGFloat = 20
    @State private var isPressed = false
    
    var isOwnMessage: Bool {
        currentUserEmail == announcement.authorEmail
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(announcement.timestamp) {
            formatter.timeStyle = .short
            return formatter.string(from: announcement.timestamp)
        } else if calendar.isDateInYesterday(announcement.timestamp) {
            formatter.timeStyle = .short
            return "Yesterday " + formatter.string(from: announcement.timestamp)
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: announcement.timestamp)
        }
    }
    
    var initials: String {
        let components = announcement.authorName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else {
            return String(announcement.authorName.prefix(2)).uppercased()
        }
    }
    
    var avatarColor: Color {
        let hash = abs(announcement.authorName.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                avatarColor,
                                avatarColor.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: avatarColor.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Text(initials)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            // Message content
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Text(announcement.authorName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text(timeString)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    if isOwnMessage {
                        Menu {
                            Button(role: .destructive, action: {
                                showDeleteAlert = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Message
                Text(announcement.message)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.08), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.15),
                                Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
        .scaleEffect(isPressed ? 0.97 : cardScale)
        .opacity(cardOpacity)
        .offset(y: cardOffset)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(index) * 0.05)) {
                cardScale = 1.0
                cardOpacity = 1.0
                cardOffset = 0
            }
        }
        .onLongPressGesture(minimumDuration: 0.3) {
            // Long press handled
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }
        .alert("Delete Announcement", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    cardScale = 0.85
                    cardOpacity = 0
                    cardOffset = -20
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDelete()
                }
            }
        } message: {
            Text("Are you sure you want to delete this announcement?")
        }
    }
}
