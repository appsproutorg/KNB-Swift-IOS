//
//  Models.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import Foundation

// MARK: - Honor Model
struct Honor: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var currentBid: Double
    var buyNowPrice: Double
    var currentWinner: String?
    var bids: [Bid]
    var isSold: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        currentBid: Double = 0,
        buyNowPrice: Double,
        currentWinner: String? = nil,
        bids: [Bid] = [],
        isSold: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.currentBid = currentBid
        self.buyNowPrice = buyNowPrice
        self.currentWinner = currentWinner
        self.bids = bids
        self.isSold = isSold
    }
}

// MARK: - Bid Model
struct Bid: Identifiable, Codable, Equatable {
    let id: UUID
    var amount: Double
    var bidderName: String
    var timestamp: Date
    var comment: String?
    
    init(
        id: UUID = UUID(),
        amount: Double,
        bidderName: String,
        timestamp: Date = Date(),
        comment: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.bidderName = bidderName
        self.timestamp = timestamp
        self.comment = comment
    }
}

// MARK: - User Model
struct User: Codable, Equatable {
    var name: String
    var email: String
    var totalPledged: Double
    var isAdmin: Bool = false
    
    // Helper to check if user is admin
    var hasAdminAccess: Bool {
        return isAdmin
    }
}

// MARK: - Kiddush Sponsorship Model
struct KiddushSponsorship: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date  // Shabbat date
    var sponsorName: String
    var sponsorEmail: String
    var occasion: String
    var isAnonymous: Bool
    var timestamp: Date  // When sponsorship was made
    var isPaid: Bool
    
    init(
        id: UUID = UUID(),
        date: Date,
        sponsorName: String,
        sponsorEmail: String,
        occasion: String,
        isAnonymous: Bool = false,
        timestamp: Date = Date(),
        isPaid: Bool = false
    ) {
        self.id = id
        self.date = date
        self.sponsorName = sponsorName
        self.sponsorEmail = sponsorEmail
        self.occasion = occasion
        self.isAnonymous = isAnonymous
        self.timestamp = timestamp
        self.isPaid = isPaid
    }
}

// MARK: - Shabbat Time Model
struct ShabbatTime: Codable, Equatable {
    var date: Date
    var candleLighting: Date
    var havdalah: Date
    var parsha: String?
    
    init(date: Date, candleLighting: Date, havdalah: Date, parsha: String? = nil) {
        self.date = date
        self.candleLighting = candleLighting
        self.havdalah = havdalah
        self.parsha = parsha
    }
}

// MARK: - Social Post Model
struct SocialPost: Identifiable, Codable, Equatable {
    let id: String
    var authorName: String
    var authorEmail: String
    var content: String
    var timestamp: Date
    var likes: [String]  // Array of user emails who liked
    var likeCount: Int
    var replyCount: Int
    var parentPostId: String?  // null for top-level posts, postId for replies
    var editedAt: Date?  // Timestamp when post was edited
    
    init(
        id: String = UUID().uuidString,
        authorName: String,
        authorEmail: String,
        content: String,
        timestamp: Date = Date(),
        likes: [String] = [],
        likeCount: Int = 0,
        replyCount: Int = 0,
        parentPostId: String? = nil,
        editedAt: Date? = nil
    ) {
        self.id = id
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.content = content
        self.timestamp = timestamp
        self.likes = likes
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.parentPostId = parentPostId
        self.editedAt = editedAt
    }
    
    var isReply: Bool {
        return parentPostId != nil
    }
    
    var isEdited: Bool {
        return editedAt != nil
    }
    
    func isLikedBy(_ userEmail: String) -> Bool {
        return likes.contains(userEmail)
    }
}

// MARK: - Notification Model
struct AppNotification: Identifiable, Codable, Equatable {
    let id: String
    let type: NotificationType
    let postId: String?
    let userId: String  // User who triggered the notification (liker/replier)
    let userName: String  // Name of user who triggered the notification
    let message: String
    let timestamp: Date
    var isRead: Bool
    
    init(
        id: String = UUID().uuidString,
        type: NotificationType,
        postId: String? = nil,
        userId: String,
        userName: String,
        message: String,
        timestamp: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.postId = postId
        self.userId = userId
        self.userName = userName
        self.message = message
        self.timestamp = timestamp
        self.isRead = isRead
    }
}

enum NotificationType: String, Codable {
    case like
    case reply
}

