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

