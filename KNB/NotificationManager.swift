//
//  NotificationManager.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class NotificationManager: ObservableObject {
    private var db: Firestore {
        return Firestore.firestore()
    }
    
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var notificationsListener: ListenerRegistration?
    var currentUserEmail: String
    
    init(currentUserEmail: String) {
        self.currentUserEmail = currentUserEmail
    }
    
    // MARK: - Start Listening
    func startListening() {
        // Stop existing listener if email changed
        if notificationsListener != nil {
            stopListening()
        }
        
        isLoading = true
        
        notificationsListener = db.collection("notifications")
            .whereField("recipientEmail", isEqualTo: currentUserEmail)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if let error = error {
                        print("❌ Error listening to notifications: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.notifications = documents.compactMap { doc -> AppNotification? in
                        let data = doc.data()
                        
                        guard let id = data["id"] as? String,
                              let typeString = data["type"] as? String,
                              let type = NotificationType(rawValue: typeString),
                              let userId = data["userId"] as? String,
                              let userName = data["userName"] as? String,
                              let message = data["message"] as? String,
                              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                              let recipientEmail = data["recipientEmail"] as? String,
                              recipientEmail == self.currentUserEmail else {
                            return nil
                        }
                        
                        let postId = data["postId"] as? String
                        let isRead = data["isRead"] as? Bool ?? false
                        
                        return AppNotification(
                            id: id,
                            type: type,
                            postId: postId,
                            userId: userId,
                            userName: userName,
                            message: message,
                            timestamp: timestamp,
                            isRead: isRead
                        )
                    }
                    
                    self.unreadCount = self.notifications.filter { !$0.isRead }.count
                }
            }
    }
    
    // MARK: - Stop Listening
    func stopListening() {
        notificationsListener?.remove()
        notificationsListener = nil
    }
    
    // MARK: - Create Notification
    func createNotification(
        type: NotificationType,
        postId: String?,
        targetUserEmail: String,
        triggeredByUserEmail: String,
        triggeredByUserName: String
    ) async -> Bool {
        // Don't notify yourself
        guard targetUserEmail != triggeredByUserEmail else { return true }
        
        let message: String
        switch type {
        case .like:
            message = "\(triggeredByUserName) liked your post"
        case .reply:
            message = "\(triggeredByUserName) replied to your post"
        }
        
        let notification = AppNotification(
            type: type,
            postId: postId,
            userId: targetUserEmail,
            userName: triggeredByUserName,
            message: message
        )
        
        do {
            let notificationRef = db.collection("notifications").document(notification.id)
            try await notificationRef.setData([
                "id": notification.id,
                "recipientEmail": targetUserEmail,
                "type": notification.type.rawValue,
                "postId": notification.postId as Any,
                "userId": notification.userId,
                "userName": notification.userName,
                "message": notification.message,
                "timestamp": Timestamp(date: notification.timestamp),
                "isRead": notification.isRead
            ])
            
            print("✅ Created notification: \(notification.id)")
            
            // Send push notification
            await sendPushNotification(
                to: targetUserEmail,
                title: "New Notification",
                body: message,
                notificationId: notification.id,
                postId: postId
            )
            
            return true
        } catch {
            print("❌ Error creating notification: \(error.localizedDescription)")
            errorMessage = "Failed to create notification: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Send Push Notification
    private func sendPushNotification(
        to userEmail: String,
        title: String,
        body: String,
        notificationId: String,
        postId: String?
    ) async {
        // Get FCM token for the user
        do {
            let userDoc = try await db.collection("users").document(userEmail).getDocument()
            
            guard let userData = userDoc.data(),
                  let fcmToken = userData["fcmToken"] as? String else {
                print("⚠️ No FCM token found for user: \(userEmail)")
                return
            }
            
            // Use Firebase Cloud Functions to send push notification
            // For now, we'll use a Firestore trigger approach
            // Create a document in a collection that triggers a Cloud Function
            
            let pushRequestRef = db.collection("push_notifications").document()
            try await pushRequestRef.setData([
                "fcmToken": fcmToken,
                "title": title,
                "body": body,
                "notificationId": notificationId,
                "postId": postId as Any,
                "userEmail": userEmail,
                "timestamp": Timestamp(date: Date()),
                "sent": false
            ])
            
            print("✅ Queued push notification for user: \(userEmail)")
        } catch {
            print("❌ Error sending push notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Mark as Read
    func markAsRead(notificationId: String) async -> Bool {
        do {
            try await db.collection("notifications").document(notificationId).updateData([
                "isRead": true
            ])
            
            // Update local state
            if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
                notifications[index].isRead = true
                unreadCount = notifications.filter { !$0.isRead }.count
            }
            
            return true
        } catch {
            print("❌ Error marking notification as read: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Mark All as Read
    func markAllAsRead() async -> Bool {
        let unreadIds = notifications.filter { !$0.isRead }.map { $0.id }
        
        guard !unreadIds.isEmpty else { return true }
        
        let batch = db.batch()
        for id in unreadIds {
            let ref = db.collection("notifications").document(id)
            batch.updateData(["isRead": true], forDocument: ref)
        }
        
        do {
            try await batch.commit()
            
            // Update local state
            for index in notifications.indices {
                notifications[index].isRead = true
            }
            unreadCount = 0
            
            return true
        } catch {
            print("❌ Error marking all notifications as read: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Delete Notification
    func deleteNotification(notificationId: String) async -> Bool {
        do {
            try await db.collection("notifications").document(notificationId).delete()
            
            // Update local state
            notifications.removeAll { $0.id == notificationId }
            unreadCount = notifications.filter { !$0.isRead }.count
            
            return true
        } catch {
            print("❌ Error deleting notification: \(error.localizedDescription)")
            return false
        }
    }
}

