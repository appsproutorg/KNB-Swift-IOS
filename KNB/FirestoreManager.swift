//
//  FirestoreManager.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class FirestoreManager: ObservableObject {
    private var db: Firestore {
        return Firestore.firestore()
    }
    @Published var honors: [Honor] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var honorsListener: ListenerRegistration?
    
    // MARK: - Initialize Honors (Run Once)
    func initializeHonorsInFirestore() async {
        let initialHonors: [Honor] = [
            // Night Honors
            Honor(name: "Candy man", description: "Kids will love you and you will share in their pure reward", buyNowPrice: 1800),
            Honor(name: "Ato Horeiso, night", description: "10 Pesukim from the Torah. Each one with Kabbalistic meaning. Merit for successful year", buyNowPrice: 1800),
            Honor(name: "Pesicha, night", description: "Open Aron Kodesh. Special merit for easy labor", buyNowPrice: 1800),
            Honor(name: "Hakafa 1, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 2, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 3, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 4, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 5, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 6, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 7, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Cohen, night", description: "If you are a cohen, this is your chance to be blessed with prosperous year. If you are not, you can pledge in honor of a cohen", buyNowPrice: 1800),
            Honor(name: "Levi, night", description: "If you are a levi, this is your chance to be blessed with prosperous year. If you are not, you can pledge in honor of a levi", buyNowPrice: 1800),
            Honor(name: "Yisroel, night", description: "Merit for \"aliya\" - elevation in material and spiritual spheres", buyNowPrice: 1800),
            Honor(name: "Hagba, gelila, night", description: "Merit for physical and emotional strength to deal with daily challenges of life", buyNowPrice: 1800),
            
            // Day Honors
            Honor(name: "Ato Horeiso, day", description: "10 Pesukim from the Torah. Each one with Kabbalistic meaning. Merit for successful year", buyNowPrice: 1800),
            Honor(name: "Pesicha, day", description: "Open Aron Kodesh. Special merit for easy labor", buyNowPrice: 1800),
            Honor(name: "Hakafa 1, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 2, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 3, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 4, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 5, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 6, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Hakafa 7, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800),
            Honor(name: "Cohen, day", description: "If you are a cohen, this is your chance to be blessed with prosperous year. If you are not, you can pledge in honor of a cohen", buyNowPrice: 1800),
            Honor(name: "Levi, day", description: "If you are a levi, this is your chance to be blessed with prosperous year. If you are not, you can pledge in honor of a levi", buyNowPrice: 1800),
            Honor(name: "Yisroel, day", description: "Merit for \"aliya\" - elevation in material and spiritual spheres", buyNowPrice: 1800),
            
            // Special Honors
            Honor(name: "Kol Hanaarim", description: "Blessing to all kids in the community. This is a merit to have more children", buyNowPrice: 10000),
            Honor(name: "Choson Torah", description: "Huge merit for spiritual success and knowledge of Torah", buyNowPrice: 25000),
            Honor(name: "Choson Bereshis", description: "Huge merit for material (financial) success", buyNowPrice: 25000),
            Honor(name: "Maftir", description: "Merit for a chance of prophecy", buyNowPrice: 1800),
            Honor(name: "Hagba, gelila, day", description: "Merit for physical and emotional strength to deal with daily challenges of life", buyNowPrice: 1800)
        ]
        
        // Check if honors already exist
        let snapshot = try? await db.collection("honors").getDocuments()
        if let count = snapshot?.documents.count, count > 0 {
            print("Honors already initialized in Firestore")
            return
        }
        
        // Add all honors to Firestore
        for honor in initialHonors {
            do {
                try await db.collection("honors").document(honor.id.uuidString).setData([
                    "id": honor.id.uuidString,
                    "name": honor.name,
                    "description": honor.description,
                    "currentBid": honor.currentBid,
                    "buyNowPrice": honor.buyNowPrice,
                    "currentWinner": honor.currentWinner as Any,
                    "isSold": honor.isSold,
                    "bids": []
                ])
                print("✅ Added honor: \(honor.name)")
            } catch {
                print("❌ Error adding honor \(honor.name): \(error)")
            }
        }
    }
    
    // MARK: - Start Real-Time Listener
    func startListening() {
        honorsListener?.remove()
        
        honorsListener = db.collection("honors")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.honors = documents.compactMap { doc -> Honor? in
                    let data = doc.data()
                    
                    guard let idString = data["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let name = data["name"] as? String,
                          let description = data["description"] as? String,
                          let buyNowPrice = data["buyNowPrice"] as? Double else {
                        return nil
                    }
                    
                    let currentBid = data["currentBid"] as? Double ?? 0
                    let currentWinner = data["currentWinner"] as? String
                    let isSold = data["isSold"] as? Bool ?? false
                    
                    // Parse bids array
                    let bidsData = data["bids"] as? [[String: Any]] ?? []
                    let bids = bidsData.compactMap { bidData -> Bid? in
                        guard let bidIdString = bidData["id"] as? String,
                              let bidId = UUID(uuidString: bidIdString),
                              let amount = bidData["amount"] as? Double,
                              let bidderName = bidData["bidderName"] as? String,
                              let timestamp = (bidData["timestamp"] as? Timestamp)?.dateValue() else {
                            return nil
                        }
                        
                        let comment = bidData["comment"] as? String
                        
                        return Bid(id: bidId, amount: amount, bidderName: bidderName, timestamp: timestamp, comment: comment)
                    }
                    
                    return Honor(
                        id: id,
                        name: name,
                        description: description,
                        currentBid: currentBid,
                        buyNowPrice: buyNowPrice,
                        currentWinner: currentWinner,
                        bids: bids,
                        isSold: isSold
                    )
                }
            }
    }
    
    // MARK: - Stop Listening
    func stopListening() {
        honorsListener?.remove()
    }
    
    // MARK: - Place Bid
    func placeBid(honorId: UUID, bid: Bid) async -> Bool {
        // Validate bid amount (max 1 million, must be positive and valid)
        let maxBidAmount: Double = 1_000_000
        guard bid.amount > 0,
              bid.amount <= maxBidAmount,
              !bid.amount.isNaN,
              !bid.amount.isInfinite else {
            errorMessage = "Invalid bid amount. Bid must be between $0 and $\(Int(maxBidAmount))"
            return false
        }
        
        do {
            let honorRef = db.collection("honors").document(honorId.uuidString)
            
            // Get current honor data
            let document = try await honorRef.getDocument()
            guard let data = document.data() else { return false }
            
            let currentBid = data["currentBid"] as? Double ?? 0
            
            // Ensure new bid is higher than current bid
            guard bid.amount > currentBid else {
                errorMessage = "Bid must be higher than current bid"
                return false
            }
            
            // Update bids array
            var bids = data["bids"] as? [[String: Any]] ?? []
            
            let newBidData: [String: Any] = [
                "id": bid.id.uuidString,
                "amount": bid.amount,
                "bidderName": bid.bidderName,
                "timestamp": Timestamp(date: bid.timestamp),
                "comment": bid.comment as Any
            ]
            
            bids.insert(newBidData, at: 0)
            
            // Update honor with new bid
            try await honorRef.updateData([
                "bids": bids,
                "currentBid": bid.amount,
                "currentWinner": bid.bidderName
            ])
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Buy Now
    func buyNow(honorId: UUID, bid: Bid) async -> Bool {
        // Validate bid amount (must be positive and valid)
        guard bid.amount > 0,
              !bid.amount.isNaN,
              !bid.amount.isInfinite else {
            errorMessage = "Invalid purchase amount"
            return false
        }
        
        do {
            let honorRef = db.collection("honors").document(honorId.uuidString)
            
            // Get current honor data
            let document = try await honorRef.getDocument()
            guard let data = document.data() else { return false }
            
            // Update bids array
            var bids = data["bids"] as? [[String: Any]] ?? []
            
            let buyNowBidData: [String: Any] = [
                "id": bid.id.uuidString,
                "amount": bid.amount,
                "bidderName": bid.bidderName,
                "timestamp": Timestamp(date: bid.timestamp),
                "comment": bid.comment as Any
            ]
            
            bids.insert(buyNowBidData, at: 0)
            
            // Update honor as sold
            try await honorRef.updateData([
                "bids": bids,
                "currentBid": bid.amount,
                "currentWinner": bid.bidderName,
                "isSold": true
            ])
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

