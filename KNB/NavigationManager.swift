//
//  NavigationManager.swift
//  KNB
//
//  Created by AI Assistant on 11/24/25.
//

import SwiftUI
import Combine

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var selectedTab: Int = 0
    
    // Deep Link States
    @Published var navigateToPostId: String?
    @Published var navigateToAuctionId: String?
    
    private init() {}
    
    func handleDeepLink(userInfo: [AnyHashable: Any]) {
        print("🔗 NavigationManager: Handling deep link with info: \(userInfo)")
        
        // Check for specific data fields
        if let postId = userInfo["postId"] as? String {
            print("🔗 Deep Link: Found postId \(postId)")
            DispatchQueue.main.async {
                self.selectedTab = 1 // Social Tab
                // Small delay to allow tab switch
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.navigateToPostId = postId
                }
            }
        } else if let honorId = userInfo["honorId"] as? String {
            print("🔗 Deep Link: Found honorId \(honorId)")
            DispatchQueue.main.async {
                self.selectedTab = 3 // More Tab (Auction is now in More menu)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.navigateToAuctionId = honorId
                }
            }
        } else if let chatThreadId = userInfo["chatThreadId"] as? String {
            print("🔗 Deep Link: Found chatThreadId \(chatThreadId)")
            DispatchQueue.main.async {
                self.selectedTab = 2 // Messages Tab
            }
        } else if let chatThreadOwnerEmail = userInfo["chatThreadOwnerEmail"] as? String {
            print("🔗 Deep Link: Found chatThreadOwnerEmail \(chatThreadOwnerEmail)")
            DispatchQueue.main.async {
                self.selectedTab = 2 // Messages Tab
            }
        } else if let type = userInfo["type"] as? String {
            // Fallback based on type if IDs are missing (though they should be there)
            switch type {
            case "ADMIN_POST", "POST_LIKE", "POST_REPLY", "REPLY_LIKE":
                DispatchQueue.main.async { self.selectedTab = 1 }
            case "OUTBID":
                DispatchQueue.main.async { self.selectedTab = 3 } // More Tab (Auction is now in More menu)
            case "CHAT_MESSAGE", "DIRECT_MESSAGE", "RABBI_MESSAGE":
                DispatchQueue.main.async { self.selectedTab = 2 } // Messages Tab
            default:
                break
            }
        }
    }
}
