//
//  NotificationListView.swift
//  KNB
//
//  Created by AI Assistant on 11/23/25.
//

import SwiftUI

struct NotificationListView: View {
    @StateObject var notificationManager: NotificationManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var firestoreManager: FirestoreManager
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if notificationManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if notificationManager.notifications.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "No Notifications",
                        message: "You're all caught up! Check back later for updates."
                    )
                } else {
                    List {
                        ForEach(notificationManager.notifications) { notification in
                            NotificationRow(notification: notification)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            await notificationManager.delete(notification)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    if !notification.isRead {
                                        Button {
                                            Task {
                                                await notificationManager.markAsRead(notification)
                                            }
                                        } label: {
                                            Label("Read", systemImage: "envelope.open")
                                        }
                                        .tint(.blue)
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        // Trigger refresh logic if needed
                    }
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if !notificationManager.notifications.isEmpty {
                            Menu {
                                Button {
                                    Task {
                                        await notificationManager.markAllAsRead()
                                    }
                                } label: {
                                    Label("Mark all as read", systemImage: "checkmark.circle")
                                }
                                
                                Button(role: .destructive) {
                                    Task {
                                        await notificationManager.deleteAll()
                                    }
                                } label: {
                                    Label("Clear all", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.gray.opacity(0.6))
                            }
                        }
                        
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.gray.opacity(0.6))
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(appSettings: appSettings)
                    .environmentObject(firestoreManager)
            }
        }
        .onAppear {
            notificationManager.startListening()
        }
        .onDisappear {
            notificationManager.stopListening()
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Text(notification.body)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        .opacity(notification.isRead ? 0.6 : 1.0)
    }
    
    private var iconName: String {
        switch notification.type {
        case .adminPost: return "megaphone.fill"
        case .postLike: return "heart.fill"
        case .postReply: return "bubble.left.fill"
        case .replyLike: return "heart.fill"
        case .outbid: return "gavel.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .adminPost: return .red
        case .postLike: return .pink
        case .postReply: return .blue
        case .replyLike: return .pink
        case .outbid: return .orange
        }
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.createdAt, relativeTo: Date())
    }
}
