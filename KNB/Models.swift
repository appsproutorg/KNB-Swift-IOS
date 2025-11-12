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

