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
    var category: String
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        currentBid: Double = 0,
        buyNowPrice: Double,
        currentWinner: String? = nil,
        bids: [Bid] = [],
        isSold: Bool = false,
        category: String = "General"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.currentBid = currentBid
        self.buyNowPrice = buyNowPrice
        self.currentWinner = currentWinner
        self.bids = bids
        self.isSold = isSold
        self.category = category
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
    var notificationPrefs: NotificationPreferences?
    var fcmTokens: [String: TokenDetails]?
    
    // Helper to check if user is admin
    var hasAdminAccess: Bool {
        return isAdmin
    }
}

struct TokenDetails: Codable, Equatable {
    let platform: String
    let updatedAt: Date
}

struct NotificationPreferences: Codable, Equatable {
    var adminPosts: Bool = true
    var postLikes: Bool = true
    var postReplies: Bool = true
    var replyLikes: Bool = true
    var outbid: Bool = true
    
    init() {}
    
    init(data: [String: Any]) {
        self.adminPosts = data["adminPosts"] as? Bool ?? true
        self.postLikes = data["postLikes"] as? Bool ?? true
        self.postReplies = data["postReplies"] as? Bool ?? true
        self.replyLikes = data["replyLikes"] as? Bool ?? true
        self.outbid = data["outbid"] as? Bool ?? true
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
    
    // Check if post is from admin account
    // Logic moved to FirestoreManager to be dynamic
    // var isAdminPost: Bool { ... }
}



// MARK: - Notification Model
struct AppNotification: Identifiable, Codable, Equatable {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let data: [String: String]? // Stores IDs like postId, replyId, auctionId
    let isRead: Bool
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        type: NotificationType,
        title: String,
        body: String,
        data: [String: String]? = nil,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.data = data
        self.isRead = isRead
        self.createdAt = createdAt
    }
}

// MARK: - Seat Reservation Model
struct SeatReservation: Identifiable, Codable, Equatable {
    let id: String
    let row: String
    let number: Int
    let reservedBy: String // User email
    let reservedByName: String // User name
    let timestamp: Date
    
    init(
        id: String = UUID().uuidString,
        row: String,
        number: Int,
        reservedBy: String,
        reservedByName: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.row = row
        self.number = number
        self.reservedBy = reservedBy
        self.reservedByName = reservedByName
        self.timestamp = timestamp
    }
}

enum NotificationType: String, Codable {
    case adminPost = "ADMIN_POST"
    case postLike = "POST_LIKE"
    case postReply = "POST_REPLY"
    case replyLike = "REPLY_LIKE"
    case outbid = "OUTBID"
    
    // Custom decoding to handle legacy lowercase values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        
        // Try to match exact raw value first
        if let type = NotificationType(rawValue: rawString) {
            self = type
            return
        }
        
        // Try case-insensitive matching for legacy data
        switch rawString.uppercased() {
        case "ADMIN_POST", "ADMINPOST": self = .adminPost
        case "POST_LIKE", "POSTLIKE": self = .postLike
        case "POST_REPLY", "POSTREPLY": self = .postReply
        case "REPLY_LIKE", "REPLYLIKE": self = .replyLike
        case "OUTBID": self = .outbid
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot initialize NotificationType from invalid String value \(rawString)"
            )
        }
    }
}
