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
    @Published var kiddushSponsorships: [KiddushSponsorship] = []
    @Published var availableDates: [Date] = []
    @Published var socialPosts: [SocialPost] = []
    @Published var lastUpdated: Date?
    
    private var honorsListener: ListenerRegistration?
    private var sponsorshipsListener: ListenerRegistration?
    private var socialPostsListener: ListenerRegistration?
    
    // Optional notification manager for creating notifications
    weak var notificationManager: NotificationManager?
    
    enum SocialPostSortOption {
        case newest
        case mostLiked
    }
    
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
        
            let honorRef = db.collection("honors").document(honorId.uuidString)
            
        // Use Firestore transaction to prevent race conditions
        do {
            // First, get the current document to check conditions
            let honorDoc = try await honorRef.getDocument()
            
            guard let data = honorDoc.data() else {
                errorMessage = "Honor not found"
                return false
            }
            
            // Check if honor is already sold
            let isSold = data["isSold"] as? Bool ?? false
            if isSold {
                errorMessage = "This honor has already been sold"
                return false
            }
            
            let currentBid = data["currentBid"] as? Double ?? 0
            
            // Ensure new bid is higher than current bid
            guard bid.amount > currentBid else {
                errorMessage = "Bid must be higher than current bid of $\(Int(currentBid))"
                return false
            }
            
            // Use a transaction to atomically update
            // Note: Using FieldValue.serverTimestamp() and atomic operations where possible
            let newBidData: [String: Any] = [
                "id": bid.id.uuidString,
                "amount": bid.amount,
                "bidderName": bid.bidderName,
                "timestamp": Timestamp(date: bid.timestamp),
                "comment": bid.comment as Any
            ]
            
            // Get current bids and add new one
            var bids = data["bids"] as? [[String: Any]] ?? []
            bids.insert(newBidData, at: 0)
            
            // Update with a check that it hasn't been sold or bid on since we read it
            try await honorRef.updateData([
                "bids": bids,
                "currentBid": bid.amount,
                "currentWinner": bid.bidderName
            ])
            
            return true
        } catch {
            // Handle errors with user-friendly messages
            if let nsError = error as NSError? {
                if nsError.domain == "TransactionError" {
                    errorMessage = nsError.localizedDescription
                } else {
                    errorMessage = "Failed to place bid. Please try again."
                }
            } else {
                errorMessage = "Failed to place bid. Please try again."
            }
            print("❌ Error placing bid: \(error.localizedDescription)")
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
        
            let honorRef = db.collection("honors").document(honorId.uuidString)
            
        // Use atomic update to prevent race conditions
        do {
            // First, get the current document to check conditions
            let honorDoc = try await honorRef.getDocument()
            
            guard let data = honorDoc.data() else {
                errorMessage = "Honor not found"
                return false
            }
            
            // Check if honor is already sold (atomic check)
            let isSold = data["isSold"] as? Bool ?? false
            if isSold {
                errorMessage = "This honor has already been sold"
                return false
            }
            
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
            
            // Update honor as sold atomically
            try await honorRef.updateData([
                "bids": bids,
                "currentBid": bid.amount,
                "currentWinner": bid.bidderName,
                "isSold": true
            ])
            
            return true
        } catch {
            // Handle errors with user-friendly messages
            if let nsError = error as NSError? {
                if nsError.domain == "TransactionError" {
                    errorMessage = nsError.localizedDescription
                } else {
                    errorMessage = "Failed to purchase honor. Please try again."
                }
            } else {
                errorMessage = "Failed to purchase honor. Please try again."
            }
            print("❌ Error buying now: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Kiddush Sponsorship Methods
    
    // Start listening to Kiddush sponsorships
    func startListeningToSponsorships() {
        sponsorshipsListener?.remove()
        
        sponsorshipsListener = db.collection("kiddush_sponsorships")
            .order(by: "date")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to sponsorships: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.kiddushSponsorships = documents.compactMap { doc -> KiddushSponsorship? in
                    let data = doc.data()
                    
                    guard let idString = data["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let date = (data["date"] as? Timestamp)?.dateValue(),
                          let sponsorName = data["sponsorName"] as? String,
                          let sponsorEmail = data["sponsorEmail"] as? String,
                          let occasion = data["occasion"] as? String,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                        return nil
                    }
                    
                    let isAnonymous = data["isAnonymous"] as? Bool ?? false
                    let isPaid = data["isPaid"] as? Bool ?? false
                    
                    return KiddushSponsorship(
                        id: id,
                        date: date,
                        sponsorName: sponsorName,
                        sponsorEmail: sponsorEmail,
                        occasion: occasion,
                        isAnonymous: isAnonymous,
                        timestamp: timestamp,
                        isPaid: isPaid
                    )
                }
            }
    }
    
    // Stop listening to sponsorships
    func stopListeningToSponsorships() {
        sponsorshipsListener?.remove()
    }
    
    // Fetch all Kiddush sponsorships
    func fetchKiddushSponsorships() async {
        do {
            let snapshot = try await db.collection("kiddush_sponsorships")
                .order(by: "date")
                .getDocuments()
            
            kiddushSponsorships = snapshot.documents.compactMap { doc -> KiddushSponsorship? in
                let data = doc.data()
                
                guard let idString = data["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let date = (data["date"] as? Timestamp)?.dateValue(),
                      let sponsorName = data["sponsorName"] as? String,
                      let sponsorEmail = data["sponsorEmail"] as? String,
                      let occasion = data["occasion"] as? String,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                
                let isAnonymous = data["isAnonymous"] as? Bool ?? false
                let isPaid = data["isPaid"] as? Bool ?? false
                
                return KiddushSponsorship(
                    id: id,
                    date: date,
                    sponsorName: sponsorName,
                    sponsorEmail: sponsorEmail,
                    occasion: occasion,
                    isAnonymous: isAnonymous,
                    timestamp: timestamp,
                    isPaid: isPaid
                )
            }
        } catch {
            print("Error fetching sponsorships: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    // Sponsor Kiddush - returns true if successful, false if date already taken
    func sponsorKiddush(_ sponsorship: KiddushSponsorship) async -> Bool {
        do {
            // CRITICAL: Always use startOfDay for consistent date comparison
            let calendar = Calendar.chicago
            let startOfDay = calendar.startOfDay(for: sponsorship.date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            print("🔍 Checking sponsorship for date: \(startOfDay)")
            
            let snapshot = try await db.collection("kiddush_sponsorships")
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("date", isLessThan: Timestamp(date: endOfDay))
                .getDocuments()
            
            print("📊 Found \(snapshot.documents.count) existing sponsorships for this date")
            
            // If there's already a sponsorship for this date, return false
            if !snapshot.documents.isEmpty {
                print("❌ Date already sponsored")
                errorMessage = "This Shabbat date has already been sponsored."
                return false
            }
            
            // Create the sponsorship - ALWAYS store with startOfDay to ensure consistency
            print("✅ Creating sponsorship for \(startOfDay)")
            print("   Storing date as: \(startOfDay) (UTC: \(startOfDay.timeIntervalSince1970))")
            
            try await db.collection("kiddush_sponsorships")
                .document(sponsorship.id.uuidString)
                .setData([
                    "id": sponsorship.id.uuidString,
                    "date": Timestamp(date: startOfDay),  // Use startOfDay!
                    "sponsorName": sponsorship.sponsorName,
                    "sponsorEmail": sponsorship.sponsorEmail,
                    "occasion": sponsorship.occasion,
                    "isAnonymous": sponsorship.isAnonymous,
                    "timestamp": Timestamp(date: sponsorship.timestamp),
                    "isPaid": sponsorship.isPaid
                ])
            
            print("🎉 Sponsorship created successfully")
            return true
        } catch {
            print("❌ Error sponsoring Kiddush: \(error.localizedDescription)")
            errorMessage = "Failed to create sponsorship: \(error.localizedDescription)"
            return false
        }
    }
    
    // Check if a date is available for sponsorship
    func isDateAvailable(_ date: Date) async -> Bool {
        do {
            let calendar = Calendar.chicago
            let startOfDay = calendar.startOfDay(for: date)
            
            let snapshot = try await db.collection("kiddush_sponsorships")
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("date", isLessThan: Timestamp(date: calendar.date(byAdding: .day, value: 1, to: startOfDay)!))
                .getDocuments()
            
            return snapshot.documents.isEmpty
        } catch {
            print("Error checking date availability: \(error.localizedDescription)")
            return false
        }
    }
    
    // Get sponsorship for a specific date
    func getSponsorship(for date: Date) -> KiddushSponsorship? {
        let calendar = Calendar.chicago
        let startOfDay = calendar.startOfDay(for: date)
        
        let found = kiddushSponsorships.first { sponsorship in
            let sponsorStartOfDay = calendar.startOfDay(for: sponsorship.date)
            return calendar.isDate(sponsorStartOfDay, inSameDayAs: startOfDay)
        }
        
        if found != nil {
            print("✅ Found sponsorship for \(startOfDay)")
        }
        
        return found
    }
    
    // Fetch available dates (admin-controlled)
    func fetchAvailableDates() async {
        // For now, all future Shabbat dates are available
        // In the future, this can be controlled by admin settings in Firestore
        do {
            let snapshot = try await db.collection("available_shabbat_dates")
                .order(by: "date")
                .getDocuments()
            
            availableDates = snapshot.documents.compactMap { doc -> Date? in
                let data = doc.data()
                return (data["date"] as? Timestamp)?.dateValue()
            }
            
            // If no admin-controlled dates exist, generate default available dates
            // (all Saturdays for the next 12 months)
            if availableDates.isEmpty {
                availableDates = generateDefaultAvailableDates()
            }
        } catch {
            print("Error fetching available dates: \(error.localizedDescription)")
            // Fallback to default dates
            availableDates = generateDefaultAvailableDates()
        }
    }
    
    // Generate default available dates (all Saturdays for next 12 months)
    private func generateDefaultAvailableDates() -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.chicago
        let today = Date()
        
        for week in 0..<52 {
            if let saturday = calendar.date(byAdding: .weekOfYear, value: week, to: today) {
                // Find the next Saturday
                var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: saturday)
                components.weekday = 7 // Saturday
                if let nextSaturday = calendar.date(from: components), nextSaturday >= today {
                    dates.append(nextSaturday)
                }
            }
        }
        
        return dates
    }
    
    // MARK: - User Sponsorship History
    
    // Get user's honors (where they are the current winner or have bids)
    func getUserHonors(userName: String) -> [Honor] {
        return honors.filter { honor in
            honor.currentWinner == userName || honor.bids.contains { $0.bidderName == userName }
        }
    }
    
    // Fetch all sponsorships for a specific user by email
    func fetchUserSponsorships(email: String) async -> [KiddushSponsorship] {
        do {
            let snapshot = try await db.collection("kiddush_sponsorships")
                .whereField("sponsorEmail", isEqualTo: email)
                .order(by: "date", descending: true)
                .getDocuments()
            
            let sponsorships = snapshot.documents.compactMap { doc -> KiddushSponsorship? in
                let data = doc.data()
                
                guard let idString = data["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let date = (data["date"] as? Timestamp)?.dateValue(),
                      let sponsorName = data["sponsorName"] as? String,
                      let sponsorEmail = data["sponsorEmail"] as? String,
                      let occasion = data["occasion"] as? String,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                
                let isAnonymous = data["isAnonymous"] as? Bool ?? false
                let isPaid = data["isPaid"] as? Bool ?? false
                
                return KiddushSponsorship(
                    id: id,
                    date: date,
                    sponsorName: sponsorName,
                    sponsorEmail: sponsorEmail,
                    occasion: occasion,
                    isAnonymous: isAnonymous,
                    timestamp: timestamp,
                    isPaid: isPaid
                )
            }
            
            print("📖 Fetched \(sponsorships.count) sponsorships for user: \(email)")
            return sponsorships
        } catch {
            print("❌ Error fetching user sponsorships: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Debug & Cleanup Methods
    
    // Debug: List all sponsorships in Firestore
    func debugListAllSponsorships() async {
        do {
            let snapshot = try await db.collection("kiddush_sponsorships").getDocuments()
            print("📋 Total sponsorships in Firestore: \(snapshot.documents.count)")
            
            for doc in snapshot.documents {
                let data = doc.data()
                if let timestamp = data["date"] as? Timestamp {
                    let date = timestamp.dateValue()
                    let calendar = Calendar.chicago
                    let startOfDay = calendar.startOfDay(for: date)
                    
                    print("   📅 ID: \(doc.documentID)")
                    print("      Date in Firestore: \(date)")
                    print("      StartOfDay would be: \(startOfDay)")
                    print("      Sponsor: \(data["sponsorEmail"] ?? "unknown")")
                }
            }
        } catch {
            print("❌ Error listing sponsorships: \(error.localizedDescription)")
        }
    }
    
    // Delete ALL sponsorships (use with caution - for testing only)
    func deleteAllSponsorships() async {
        do {
            let snapshot = try await db.collection("kiddush_sponsorships").getDocuments()
            print("🗑️ Deleting \(snapshot.documents.count) sponsorships...")
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
                print("   ✅ Deleted: \(doc.documentID)")
            }
            
            print("✅ All sponsorships deleted")
        } catch {
            print("❌ Error deleting sponsorships: \(error.localizedDescription)")
        }
    }
    
    // Delete a specific sponsorship by date
    func deleteSponsorshipByDate(_ date: Date) async {
        do {
            let calendar = Calendar.chicago
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let snapshot = try await db.collection("kiddush_sponsorships")
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("date", isLessThan: Timestamp(date: endOfDay))
                .getDocuments()
            
            print("🗑️ Found \(snapshot.documents.count) sponsorship(s) for \(startOfDay)")
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
                print("   ✅ Deleted sponsorship: \(doc.documentID)")
            }
        } catch {
            print("❌ Error deleting sponsorship: \(error.localizedDescription)")
        }
    }
    
    // Fix malformed dates in Firestore (normalize all dates to startOfDay)
    func fixMalformedDates() async {
        do {
            let snapshot = try await db.collection("kiddush_sponsorships").getDocuments()
            print("🔧 Fixing \(snapshot.documents.count) sponsorships...")
            
            let calendar = Calendar.chicago
            
            for doc in snapshot.documents {
                let data = doc.data()
                if let timestamp = data["date"] as? Timestamp {
                    let oldDate = timestamp.dateValue()
                    let startOfDay = calendar.startOfDay(for: oldDate)
                    
                    // Only update if the date has a time component
                    if !calendar.isDate(oldDate, inSameDayAs: startOfDay) || oldDate != startOfDay {
                        try await doc.reference.updateData([
                            "date": Timestamp(date: startOfDay)
                        ])
                        print("   ✅ Fixed \(doc.documentID): \(oldDate) → \(startOfDay)")
                    }
                }
            }
            
            print("🎉 Date normalization complete!")
        } catch {
            print("❌ Error fixing dates: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Admin/Debug Functions
    
    // Reset all bids (clear all bids, reset currentBid to 0, mark as not sold)
    func resetAllBids() async -> Bool {
        do {
            let snapshot = try await db.collection("honors").getDocuments()
            print("🔄 Resetting bids for \(snapshot.documents.count) honors...")
            
            for doc in snapshot.documents {
                try await doc.reference.updateData([
                    "bids": [],
                    "currentBid": 0,
                    "currentWinner": NSNull(),
                    "isSold": false
                ])
                print("   ✅ Reset bids for: \(doc.documentID)")
            }
            
            print("🎉 All bids reset successfully!")
            return true
        } catch {
            print("❌ Error resetting bids: \(error.localizedDescription)")
            errorMessage = "Failed to reset bids: \(error.localizedDescription)"
            return false
        }
    }
    
    // Reset all honors to initial state (completely re-initialize)
    func resetAllHonors() async -> Bool {
        do {
            // First, delete all existing honors
            let snapshot = try await db.collection("honors").getDocuments()
            print("🗑️ Deleting \(snapshot.documents.count) existing honors...")
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
            
            print("✅ All honors deleted")
            
            // Now re-initialize with default honors
            print("🔄 Re-initializing honors...")
            await initializeHonorsInFirestore()
            
            print("🎉 All honors reset to initial state!")
            return true
        } catch {
            print("❌ Error resetting honors: \(error.localizedDescription)")
            errorMessage = "Failed to reset honors: \(error.localizedDescription)"
            return false
        }
    }
    
    // Delete all honors (use with extreme caution!)
    func deleteAllHonors() async -> Bool {
        do {
            let snapshot = try await db.collection("honors").getDocuments()
            print("🗑️ Deleting \(snapshot.documents.count) honors...")
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
                print("   ✅ Deleted: \(doc.documentID)")
            }
            
            print("✅ All honors deleted")
            return true
        } catch {
            print("❌ Error deleting honors: \(error.localizedDescription)")
            errorMessage = "Failed to delete honors: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Social Posts
    
    // Start listening to social posts with real-time updates
    func startListeningToSocialPosts(sortBy: SocialPostSortOption = .newest) {
        socialPostsListener?.remove()
        
        // Query all posts, then filter for top-level posts (parentPostId is null or missing)
        let query: Query
        switch sortBy {
        case .newest:
            query = db.collection("social_posts")
                .order(by: "timestamp", descending: true)
        case .mostLiked:
            query = db.collection("social_posts")
                .order(by: "likeCount", descending: true)
                .order(by: "timestamp", descending: true)
        }
        
        socialPostsListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error listening to social posts: \(error.localizedDescription)")
                self.errorMessage = "Failed to load posts: \(error.localizedDescription)"
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ No social posts documents found")
                return
            }
            
            let allPosts = documents.compactMap { doc -> SocialPost? in
                let data = doc.data()
                
                guard let id = data["id"] as? String,
                      let authorName = data["authorName"] as? String,
                      let authorEmail = data["authorEmail"] as? String,
                      let content = data["content"] as? String,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                
                let likes = data["likes"] as? [String] ?? []
                let likeCount = data["likeCount"] as? Int ?? 0
                let replyCount = data["replyCount"] as? Int ?? 0
                let parentPostId = data["parentPostId"] as? String
                let editedAt = (data["editedAt"] as? Timestamp)?.dateValue()
                
                return SocialPost(
                    id: id,
                    authorName: authorName,
                    authorEmail: authorEmail,
                    content: content,
                    timestamp: timestamp,
                    likes: likes,
                    likeCount: likeCount,
                    replyCount: replyCount,
                    parentPostId: parentPostId,
                    editedAt: editedAt
                )
            }
            
            // Filter to only top-level posts (no parentPostId)
            self.socialPosts = allPosts.filter { $0.parentPostId == nil }
            
            // Re-sort if needed (since we filtered)
            switch sortBy {
            case .newest:
                self.socialPosts.sort { $0.timestamp > $1.timestamp }
            case .mostLiked:
                self.socialPosts.sort {
                    if $0.likeCount != $1.likeCount {
                        return $0.likeCount > $1.likeCount
                    }
                    return $0.timestamp > $1.timestamp
                }
            }
            
            self.lastUpdated = Date()
            print("✅ Loaded \(self.socialPosts.count) social posts")
        }
    }
    
    // Stop listening to social posts
    func stopListeningToSocialPosts() {
        socialPostsListener?.remove()
        socialPostsListener = nil
    }
    
    // Fetch social posts (one-time fetch)
    func fetchSocialPosts(sortBy: SocialPostSortOption = .newest) async {
        do {
            // Query all posts, then filter for top-level posts
            let query: Query
            switch sortBy {
            case .newest:
                query = db.collection("social_posts")
                    .order(by: "timestamp", descending: true)
            case .mostLiked:
                query = db.collection("social_posts")
                    .order(by: "likeCount", descending: true)
                    .order(by: "timestamp", descending: true)
            }
            
            let snapshot = try await query.getDocuments()
            
            let allPosts = snapshot.documents.compactMap { doc -> SocialPost? in
                let data = doc.data()
                
                guard let id = data["id"] as? String,
                      let authorName = data["authorName"] as? String,
                      let authorEmail = data["authorEmail"] as? String,
                      let content = data["content"] as? String,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                
                let likes = data["likes"] as? [String] ?? []
                let likeCount = data["likeCount"] as? Int ?? 0
                let replyCount = data["replyCount"] as? Int ?? 0
                let parentPostId = data["parentPostId"] as? String
                
                return SocialPost(
                    id: id,
                    authorName: authorName,
                    authorEmail: authorEmail,
                    content: content,
                    timestamp: timestamp,
                    likes: likes,
                    likeCount: likeCount,
                    replyCount: replyCount,
                    parentPostId: parentPostId
                )
            }
            
            // Filter to only top-level posts (no parentPostId)
            socialPosts = allPosts.filter { $0.parentPostId == nil }
            
            // Re-sort if needed
            switch sortBy {
            case .newest:
                socialPosts.sort { $0.timestamp > $1.timestamp }
            case .mostLiked:
                socialPosts.sort {
                    if $0.likeCount != $1.likeCount {
                        return $0.likeCount > $1.likeCount
                    }
                    return $0.timestamp > $1.timestamp
                }
            }
            
            print("✅ Fetched \(socialPosts.count) social posts")
        } catch {
            print("❌ Error fetching social posts: \(error.localizedDescription)")
            errorMessage = "Failed to fetch posts: \(error.localizedDescription)"
        }
    }
    
    // Create a new social post
    func createSocialPost(content: String, author: User) async -> Bool {
        guard content.count <= 140 else {
            errorMessage = "Post must be 140 characters or less"
            return false
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Post cannot be empty"
            return false
        }
        
        do {
            let post = SocialPost(
                authorName: author.name,
                authorEmail: author.email,
                content: content.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            try await db.collection("social_posts").document(post.id).setData([
                "id": post.id,
                "authorName": post.authorName,
                "authorEmail": post.authorEmail,
                "content": post.content,
                "timestamp": Timestamp(date: post.timestamp),
                "likes": [],
                "likeCount": 0,
                "replyCount": 0,
                "parentPostId": NSNull(),
                "editedAt": NSNull()
            ])
            
            print("✅ Created social post: \(post.id)")
            return true
        } catch {
            print("❌ Error creating social post: \(error.localizedDescription)")
            errorMessage = "Failed to create post: \(error.localizedDescription)"
            return false
        }
    }
    
    // Update a social post
    func updateSocialPost(postId: String, content: String) async -> Bool {
        guard content.count <= 140 else {
            errorMessage = "Post must be 140 characters or less"
            return false
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Post cannot be empty"
            return false
        }
        
        do {
            try await db.collection("social_posts").document(postId).updateData([
                "content": content.trimmingCharacters(in: .whitespacesAndNewlines),
                "editedAt": Timestamp(date: Date())
            ])
            
            print("✅ Updated social post: \(postId)")
            return true
        } catch {
            print("❌ Error updating social post: \(error.localizedDescription)")
            errorMessage = "Failed to update post: \(error.localizedDescription)"
            return false
        }
    }
    
    // Toggle like on a post
    func toggleLike(postId: String, userEmail: String, userName: String? = nil) async -> Bool {
        do {
            let postRef = db.collection("social_posts").document(postId)
            let postDoc = try await postRef.getDocument()
            
            guard let data = postDoc.data(),
                  var likes = data["likes"] as? [String] else {
                errorMessage = "Post not found"
                return false
            }
            
            var likeCount = data["likeCount"] as? Int ?? 0
            
            let wasLiked = likes.contains(userEmail)
            let postAuthorEmail = data["authorEmail"] as? String ?? ""
            
            if wasLiked {
                // Unlike
                likes.removeAll { $0 == userEmail }
                likeCount = max(0, likeCount - 1)
            } else {
                // Like
                likes.append(userEmail)
                likeCount += 1
                
                // Create notification for post author (if not liking own post)
                if let notificationManager = notificationManager, postAuthorEmail != userEmail {
                    let currentUserName = userName ?? "Someone"
                    _ = await notificationManager.createNotification(
                        type: .like,
                        postId: postId,
                        targetUserEmail: postAuthorEmail,
                        triggeredByUserEmail: userEmail,
                        triggeredByUserName: currentUserName
                    )
                }
            }
            
            try await postRef.updateData([
                "likes": likes,
                "likeCount": likeCount
            ])
            
            print("✅ Toggled like for post: \(postId)")
            return true
        } catch {
            print("❌ Error toggling like: \(error.localizedDescription)")
            errorMessage = "Failed to like post: \(error.localizedDescription)"
            return false
        }
    }
    
    // Create a reply to a post
    func createReply(parentPostId: String, content: String, author: User) async -> Bool {
        guard content.count <= 140 else {
            errorMessage = "Reply must be 140 characters or less"
            return false
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Reply cannot be empty"
            return false
        }
        
        do {
            let reply = SocialPost(
                authorName: author.name,
                authorEmail: author.email,
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                parentPostId: parentPostId
            )
            
            // Create the reply
            try await db.collection("social_posts").document(reply.id).setData([
                "id": reply.id,
                "authorName": reply.authorName,
                "authorEmail": reply.authorEmail,
                "content": reply.content,
                "timestamp": Timestamp(date: reply.timestamp),
                "likes": [],
                "likeCount": 0,
                "replyCount": 0,
                "parentPostId": parentPostId
            ])
            
            // Update parent post reply count
            let parentRef = db.collection("social_posts").document(parentPostId)
            let parentDoc = try await parentRef.getDocument()
            
            if let parentData = parentDoc.data() {
                let currentReplyCount = parentData["replyCount"] as? Int ?? 0
                try await parentRef.updateData([
                    "replyCount": currentReplyCount + 1
                ])
                
                // Create notification for parent post author (if not replying to own post)
                if let notificationManager = notificationManager {
                    let parentAuthorEmail = parentData["authorEmail"] as? String ?? ""
                    if parentAuthorEmail != author.email {
                        _ = await notificationManager.createNotification(
                            type: .reply,
                            postId: parentPostId,
                            targetUserEmail: parentAuthorEmail,
                            triggeredByUserEmail: author.email,
                            triggeredByUserName: author.name
                        )
                    }
                }
            }
            
            print("✅ Created reply: \(reply.id) for post: \(parentPostId)")
            return true
        } catch {
            print("❌ Error creating reply: \(error.localizedDescription)")
            errorMessage = "Failed to create reply: \(error.localizedDescription)"
            return false
        }
    }
    
    // Fetch replies for a post
    func fetchReplies(for postId: String) async -> [SocialPost] {
        do {
            let snapshot = try await db.collection("social_posts")
                .whereField("parentPostId", isEqualTo: postId)
                .order(by: "timestamp", descending: false)
                .getDocuments()
            
            let replies = snapshot.documents.compactMap { doc -> SocialPost? in
                let data = doc.data()
                
                guard let id = data["id"] as? String,
                      let authorName = data["authorName"] as? String,
                      let authorEmail = data["authorEmail"] as? String,
                      let content = data["content"] as? String,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                
                let likes = data["likes"] as? [String] ?? []
                let likeCount = data["likeCount"] as? Int ?? 0
                let replyCount = data["replyCount"] as? Int ?? 0
                let parentPostId = data["parentPostId"] as? String
                let editedAt = (data["editedAt"] as? Timestamp)?.dateValue()
                
                return SocialPost(
                    id: id,
                    authorName: authorName,
                    authorEmail: authorEmail,
                    content: content,
                    timestamp: timestamp,
                    likes: likes,
                    likeCount: likeCount,
                    replyCount: replyCount,
                    parentPostId: parentPostId,
                    editedAt: editedAt
                )
            }
            
            print("✅ Fetched \(replies.count) replies for post: \(postId)")
            return replies
        } catch {
            print("❌ Error fetching replies: \(error.localizedDescription)")
            return []
        }
    }
    
    // Delete a social post
    func deleteSocialPost(postId: String) async -> Bool {
        do {
            // Get the post to check if it's a reply
            let postDoc = try await db.collection("social_posts").document(postId).getDocument()
            guard let postData = postDoc.data() else {
                errorMessage = "Post not found"
                return false
            }
            
            let parentPostId = postData["parentPostId"] as? String
            let batch = db.batch()
            
            // If this is a reply, decrement parent's replyCount
            if let parentId = parentPostId {
                let parentRef = db.collection("social_posts").document(parentId)
                let parentDoc = try await parentRef.getDocument()
                
                if let parentData = parentDoc.data() {
                    let currentReplyCount = parentData["replyCount"] as? Int ?? 0
                    let newReplyCount = max(0, currentReplyCount - 1)
                    batch.updateData(["replyCount": newReplyCount], forDocument: parentRef)
                }
            } else {
                // If this is a top-level post, delete all replies and reset replyCount
                let repliesSnapshot = try await db.collection("social_posts")
                    .whereField("parentPostId", isEqualTo: postId)
                    .getDocuments()
                
                for replyDoc in repliesSnapshot.documents {
                    batch.deleteDocument(replyDoc.reference)
                }
            }
            
            // Delete the post itself
            batch.deleteDocument(db.collection("social_posts").document(postId))
            
            // Commit all changes atomically
            try await batch.commit()
            
            print("✅ Deleted social post: \(postId)")
            return true
        } catch {
            print("❌ Error deleting social post: \(error.localizedDescription)")
            errorMessage = "Failed to delete post: \(error.localizedDescription)"
            return false
        }
    }
    
    // Delete all social posts (admin only)
    func deleteAllSocialPosts() async -> Bool {
        do {
            let snapshot = try await db.collection("social_posts").getDocuments()
            print("🗑️ Deleting \(snapshot.documents.count) social posts...")
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
                print("   ✅ Deleted: \(doc.documentID)")
            }
            
            print("✅ All social posts deleted")
            return true
        } catch {
            print("❌ Error deleting social posts: \(error.localizedDescription)")
            errorMessage = "Failed to delete social posts: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - User Management
    
    // Create or update user document in Firestore
    func createOrUpdateUser(user: User) async -> Bool {
        do {
            let userRef = db.collection("users").document(user.email)
            try await userRef.setData([
                "name": user.name,
                "email": user.email,
                "totalPledged": user.totalPledged,
                "isAdmin": user.isAdmin,
                "lastUpdated": Timestamp(date: Date())
            ], merge: true)
            
            print("✅ User document synced: \(user.email)")
            return true
        } catch {
            print("❌ Error syncing user: \(error.localizedDescription)")
            errorMessage = "Failed to sync user data: \(error.localizedDescription)"
            return false
        }
    }
    
    // Fetch user data from Firestore
    func fetchUserData(email: String) async -> User? {
        do {
            let userDoc = try await db.collection("users").document(email).getDocument()
            
            guard let data = userDoc.data() else {
                // User document doesn't exist yet, return nil
                return nil
            }
            
            let name = data["name"] as? String ?? "Member"
            let totalPledged = data["totalPledged"] as? Double ?? 0
            let isAdmin = data["isAdmin"] as? Bool ?? false
            
            return User(
                name: name,
                email: email,
                totalPledged: totalPledged,
                isAdmin: isAdmin
            )
        } catch {
            print("❌ Error fetching user data: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Update user's totalPledged amount
    func updateUserTotalPledged(email: String, amount: Double) async -> Bool {
        do {
            let userRef = db.collection("users").document(email)
            try await userRef.updateData([
                "totalPledged": amount,
                "lastUpdated": Timestamp(date: Date())
            ])
            
            print("✅ Updated totalPledged for \(email): $\(amount)")
            return true
        } catch {
            print("❌ Error updating totalPledged: \(error.localizedDescription)")
            errorMessage = "Failed to update total pledged: \(error.localizedDescription)"
            return false
        }
    }
    
}



