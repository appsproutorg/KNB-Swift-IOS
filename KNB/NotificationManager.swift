//
//  NotificationManager.swift
//  KNB
//
//  Created by AI Assistant on 11/23/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class NotificationManager: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    var currentUserEmail: String
    
    init(currentUserEmail: String) {
        self.currentUserEmail = currentUserEmail
    }
    
    func startListening() {
        guard !currentUserEmail.isEmpty else { return }
        
        isLoading = true
        
        print("🔔 NotificationManager: Starting listener for \(currentUserEmail)")
        
        // Listen to notifications subcollection ordered by creation time
        listener = db.collection("users")
            .document(currentUserEmail)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("❌ NotificationManager Error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("🔔 NotificationManager: No documents found")
                    return
                }
                
                print("🔔 NotificationManager: Received \(documents.count) notifications")
                
                self.notifications = documents.compactMap { doc -> AppNotification? in
                    do {
                        return try doc.data(as: AppNotification.self)
                    } catch {
                        print("❌ Failed to decode notification \(doc.documentID): \(error)")
                        // Try to print the raw data to see what's wrong
                        print("   Raw Data: \(doc.data())")
                        return nil
                    }
                }
                
                print("🔔 NotificationManager: Successfully decoded \(self.notifications.count) out of \(documents.count) documents")
                
                // Update unread count
                self.unreadCount = self.notifications.filter { !$0.isRead }.count
                print("🔔 NotificationManager: Unread count: \(self.unreadCount)")
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    func markAsRead(_ notification: AppNotification) async {
        guard !currentUserEmail.isEmpty else { return }
        
        // Optimistic update
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = AppNotification(
                id: notification.id,
                type: notification.type,
                title: notification.title,
                body: notification.body,
                data: notification.data,
                isRead: true,
                createdAt: notification.createdAt
            )
            unreadCount = notifications.filter { !$0.isRead }.count
        }
        
        do {
            try await db.collection("users")
                .document(currentUserEmail)
                .collection("notifications")
                .document(notification.id)
                .updateData(["isRead": true])
        } catch {
            print("Error marking notification as read: \(error.localizedDescription)")
        }
    }
    
    func markAllAsRead() async {
        guard !currentUserEmail.isEmpty else { return }
        
        let batch = db.batch()
        let unreadNotifications = notifications.filter { !$0.isRead }
        
        for notification in unreadNotifications {
            let ref = db.collection("users")
                .document(currentUserEmail)
                .collection("notifications")
                .document(notification.id)
            batch.updateData(["isRead": true], forDocument: ref)
        }
        
        // Optimistic update
        notifications = notifications.map {
            AppNotification(
                id: $0.id,
                type: $0.type,
                title: $0.title,
                body: $0.body,
                data: $0.data,
                isRead: true,
                createdAt: $0.createdAt
            )
        }
        unreadCount = 0
        
        do {
            try await batch.commit()
        } catch {
            print("Error marking all as read: \(error.localizedDescription)")
        }
    }
    
    func delete(_ notification: AppNotification) async {
        guard !currentUserEmail.isEmpty else { return }
        
        // Optimistic update
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications.remove(at: index)
            unreadCount = notifications.filter { !$0.isRead }.count
        }
        
        do {
            try await db.collection("users")
                .document(currentUserEmail)
                .collection("notifications")
                .document(notification.id)
                .delete()
            print("✅ Deleted notification \(notification.id)")
        } catch {
            print("❌ Error deleting notification: \(error.localizedDescription)")
            // Revert optimistic update if needed (optional, but good practice)
        }
    }
    
    func deleteAll() async {
        guard !currentUserEmail.isEmpty else { return }
        
        // Optimistic update
        notifications.removeAll()
        unreadCount = 0
        
        let batch = db.batch()
        
        do {
            let snapshot = try await db.collection("users")
                .document(currentUserEmail)
                .collection("notifications")
                .getDocuments()
            
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            
            try await batch.commit()
            print("✅ Deleted all notifications")
        } catch {
            print("❌ Error deleting all notifications: \(error.localizedDescription)")
            // Ideally revert optimistic update here, but for "delete all" it's complex
        }
    }
}

