//
//  NotificationView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct NotificationView: View {
    @ObservedObject var notificationManager: NotificationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if notificationManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if notificationManager.notifications.isEmpty {
                    EmptyNotificationsView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notificationManager.notifications) { notification in
                                NotificationRow(notification: notification, notificationManager: notificationManager)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !notificationManager.notifications.isEmpty {
                        Button("Mark All Read") {
                            Task {
                                _ = await notificationManager.markAllAsRead()
                            }
                        }
                        .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .onAppear {
                // Mark all as read when viewing
                Task {
                    _ = await notificationManager.markAllAsRead()
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                
                Text(timeAgoString(from: notification.timestamp))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .onTapGesture {
            Task {
                _ = await notificationManager.markAsRead(notificationId: notification.id)
            }
        }
    }
    
    private var iconName: String {
        switch notification.type {
        case .like:
            return "heart.fill"
        case .reply:
            return "bubble.left.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .like:
            return .red
        case .reply:
            return .blue
        }
    }
    
    private var iconBackgroundColor: Color {
        switch notification.type {
        case .like:
            return Color.red.opacity(0.1)
        case .reply:
            return Color.blue.opacity(0.1)
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyNotificationsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Notifications")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("You're all caught up!")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NotificationView(notificationManager: NotificationManager(currentUserEmail: "test@example.com"))
}

