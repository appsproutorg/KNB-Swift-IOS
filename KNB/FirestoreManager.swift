//
//  FirestoreManager.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine
import SwiftUI

@MainActor
class FirestoreManager: ObservableObject {
    private var db: Firestore {
        return Firestore.firestore()
    }
    private let storage = Storage.storage()
    @Published var honors: [Honor] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var kiddushSponsorships: [KiddushSponsorship] = []
    @Published var communityOccasions: [CommunityOccasionItem] = []
    @Published var availableDates: [Date] = []
    @Published var socialPosts: [SocialPost] = []
    @Published var lastUpdated: Date?
    @Published var currentUser: User?
    @Published var adminEmails: Set<String> = ["admin@knb.com"] // Always include super admin
    @Published var seatReservations: [SeatReservation] = []
    
    private var honorsListener: ListenerRegistration?
    private var sponsorshipsListener: ListenerRegistration?
    private var communityOccasionsListener: ListenerRegistration?
    private var socialPostsListener: ListenerRegistration?
    private var seatReservationsListener: ListenerRegistration?

    private let scrapedKiddushCollection = "kiddushCalendar"
    private let communityOccasionsCollection = "communityOccasions"
    private let scrapedSponsorEmailPlaceholder = "website@heritagecongregation.com"
    

    
    enum SocialPostSortOption {
        case newest
        case mostLiked
    }
    
    // MARK: - Initialize Honors (Run Once)
    func initializeHonorsInFirestore() async {
        // Check if honors already exist
        do {
            let snapshot = try await db.collection("honors").getDocuments()
            if !snapshot.documents.isEmpty {
                print("Honors already initialized in Firestore")
                return
            }
        } catch {
            print("❌ Error checking for existing honors: \(error.localizedDescription)")
            return
        }
        
        let initialHonors: [Honor] = [
            // Night Honors
            Honor(name: "Candy man", description: "Kids will love you and you will share in their pure reward", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Ato Horeiso, night", description: "10 Pesukim from the Torah. Each one with Kabbalistic meaning. Merit for successful year", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Pesicha, night", description: "Open Aron Kodesh. Special merit for easy labor", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Hakafa 1, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Hakafa 2, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Hakafa 3, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Hakafa 4, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Hakafa 5, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Hakafa 6, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Hakafa 7, night", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Cohen, night", description: "If you are a cohen, this is your chance to be blessed with prosperous year. If you are not, you can pledge in honor of a cohen", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Levi, night", description: "If you are a levi, this is your chance to be blessed with prosperous year. If you are not, you can pledge in honor of a levi", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Yisroel, night", description: "Merit for \"aliya\" - elevation in material and spiritual spheres", buyNowPrice: 1800, category: "Night Honors"),
            Honor(name: "Hagba, gelila, night", description: "Merit for physical and emotional strength to deal with daily challenges of life", buyNowPrice: 1800, category: "Night Honors"),
            
            // Day Honors
            Honor(name: "Ato Horeiso, day", description: "10 Pesukim from the Torah. Each one with Kabbalistic meaning. Merit for successful year", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Pesicha, day", description: "Open Aron Kodesh. Special merit for easy labor", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Hakafa 1, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Hakafa 2, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Hakafa 3, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Hakafa 4, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Hakafa 5, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Hakafa 6, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Hakafa 7, day", description: "Dancing with the Torah. Merit for wisdom", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Cohen, day", description: "If you are a cohen, this is your chance to be blessed with prosperous year. If you are not, you can pledge in honor of a cohen", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Levi, day", description: "If you are a levi, this is your chance to be blessed with prosperous year. If you are not, you can pledge in honor of a levi", buyNowPrice: 1800, category: "Day Honors"),
            Honor(name: "Yisroel, day", description: "Merit for \"aliya\" - elevation in material and spiritual spheres", buyNowPrice: 1800, category: "Day Honors"),
            
            // Special Honors
            Honor(name: "Kol Hanaarim", description: "Blessing to all kids in the community. This is a merit to have more children", buyNowPrice: 10000, category: "Special Honors"),
            Honor(name: "Choson Torah", description: "Huge merit for spiritual success and knowledge of Torah", buyNowPrice: 25000, category: "Special Honors"),
            Honor(name: "Choson Bereshis", description: "Huge merit for material (financial) success", buyNowPrice: 25000, category: "Special Honors"),
            Honor(name: "Maftir", description: "Merit for a chance of prophecy", buyNowPrice: 1800, category: "Special Honors"),
            Honor(name: "Hagba, gelila, day", description: "Merit for physical and emotional strength to deal with daily challenges of life", buyNowPrice: 1800, category: "Day Honors")
        ]
        
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
                    "category": honor.category,
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
        honorsListener = nil
        stopListeningToSponsorships()
        stopListeningToCommunityOccasions()
        stopListeningToSocialPosts()
        stopListeningToSeatReservations()
        stopListeningToUser()
    }

    deinit {
        honorsListener?.remove()
        sponsorshipsListener?.remove()
        communityOccasionsListener?.remove()
        socialPostsListener?.remove()
        seatReservationsListener?.remove()
        userListener?.remove()
    }
    
    // MARK: - Fetch Honors (One-time)
    func fetchHonors() async {
        do {
            let snapshot = try await db.collection("honors").getDocuments()
            let documents = snapshot.documents
            
            DispatchQueue.main.async {
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
                    let category = data["category"] as? String ?? "General"
                    
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
                        isSold: isSold,
                        category: category
                    )
                }
            }
        } catch {
            print("Error fetching honors: \(error)")
        }
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
        
        do {
            // Use Firestore transaction to prevent race conditions
            let _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                let honorDoc: DocumentSnapshot
                do {
                    honorDoc = try transaction.getDocument(honorRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                guard let data = honorDoc.data() else {
                    let error = NSError(domain: "AppError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Honor not found"])
                    errorPointer?.pointee = error
                    return nil
                }
                
                // Check if honor is already sold
                let isSold = data["isSold"] as? Bool ?? false
                if isSold {
                    let error = NSError(domain: "AppError", code: 400, userInfo: [NSLocalizedDescriptionKey: "This honor has already been sold"])
                    errorPointer?.pointee = error
                    return nil
                }
                
                let currentBid = data["currentBid"] as? Double ?? 0
                
                // Ensure new bid is higher than current bid
                if bid.amount <= currentBid {
                    let error = NSError(domain: "AppError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Bid must be higher than current bid of $\(Int(currentBid))"])
                    errorPointer?.pointee = error
                    return nil
                }
                
                // Prepare new bid data
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
                
                // Update document
                transaction.updateData([
                    "bids": bids,
                    "currentBid": bid.amount,
                    "currentWinner": bid.bidderName
                ], forDocument: honorRef)
                
                return nil
            })
            
            return true
        } catch {
            print("❌ Error placing bid: \(error.localizedDescription)")
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
        
        let honorRef = db.collection("honors").document(honorId.uuidString)
        
        do {
            // Use Firestore transaction to prevent race conditions
            let _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                let honorDoc: DocumentSnapshot
                do {
                    honorDoc = try transaction.getDocument(honorRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                guard let data = honorDoc.data() else {
                    let error = NSError(domain: "AppError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Honor not found"])
                    errorPointer?.pointee = error
                    return nil
                }
                
                // Check if honor is already sold
                let isSold = data["isSold"] as? Bool ?? false
                if isSold {
                    let error = NSError(domain: "AppError", code: 400, userInfo: [NSLocalizedDescriptionKey: "This honor has already been sold"])
                    errorPointer?.pointee = error
                    return nil
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
                
                // Update honor as sold
                transaction.updateData([
                    "bids": bids,
                    "currentBid": bid.amount,
                    "currentWinner": bid.bidderName,
                    "isSold": true
                ], forDocument: honorRef)
                
                return nil
            })
            
            return true
        } catch {
            print("❌ Error buying now: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Kiddush Sponsorship Methods
    private func decodeTierAmount(from data: [String: Any]) -> Int {
        if let value = data["tierAmount"] as? Int {
            return value
        }
        if let value = data["tierAmount"] as? Int64 {
            return Int(value)
        }
        if let value = data["tierAmount"] as? Double {
            return Int(value)
        }
        if let value = data["tierAmount"] as? NSNumber {
            return value.intValue
        }
        if let value = data["tierAmount"] as? String, let parsed = Int(value) {
            return parsed
        }
        if let tierName = data["tierName"] as? String {
            let normalized = tierName.lowercased()
            if normalized.contains("platinum") {
                return 700
            }
            if normalized.contains("silver") || normalized.contains("co-sponsored") {
                return 360
            }
            if normalized.contains("gold") {
                return 500
            }
        }
        return 500
    }

    private func chicagoIsoFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/Chicago")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    private func parseSponsorName(from sponsorText: String) -> String {
        let lower = sponsorText.lowercased()
        let prefixes = [
            "kiddush is sponsored by ",
            "kiddush is sponosored by ", // source typo appears on website
            "sponsored by ",
            "sponosored by ",
        ]

        var startOffset: Int?
        for prefix in prefixes {
            if let range = lower.range(of: prefix) {
                startOffset = lower.distance(from: lower.startIndex, to: range.upperBound)
                break
            }
        }

        guard let startOffset else {
            return "Reserved"
        }

        guard startOffset < sponsorText.count else {
            return "Reserved"
        }

        let startIndex = sponsorText.index(sponsorText.startIndex, offsetBy: startOffset)
        let remaining = String(sponsorText[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if remaining.isEmpty {
            return "Reserved"
        }

        let separators = [" on occasion of ", " in honor of ", "."]
        let remainingLower = remaining.lowercased()
        var cutIndex = remaining.endIndex
        for separator in separators {
            if let separatorRange = remainingLower.range(of: separator) {
                let offset = remainingLower.distance(from: remainingLower.startIndex, to: separatorRange.lowerBound)
                let candidate = remaining.index(remaining.startIndex, offsetBy: offset)
                if candidate < cutIndex {
                    cutIndex = candidate
                }
            }
        }

        let name = String(remaining[..<cutIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Reserved" : name
    }

    private func mapScrapedCalendarDocToSponsorship(docId: String, data: [String: Any]) -> KiddushSponsorship? {
        let status = (data["status"] as? String ?? "").lowercased()
        guard status == "reserved" else {
            return nil
        }

        let isoDate = (data["isoDate"] as? String) ?? docId
        let formatter = chicagoIsoFormatter()
        guard let date = formatter.date(from: isoDate) else {
            return nil
        }

        let sponsorText = (data["sponsorText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sponsorName = sponsorText.isEmpty ? "Reserved" : parseSponsorName(from: sponsorText)
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return KiddushSponsorship(
            id: UUID(),
            date: date,
            sponsorName: sponsorName,
            sponsorEmail: scrapedSponsorEmailPlaceholder,
            occasion: sponsorText.isEmpty ? "Reserved" : sponsorText,
            tierName: "Website Reserved",
            tierAmount: 0,
            isAnonymous: false,
            timestamp: updatedAt,
            isPaid: true
        )
    }
    
    // Start listening to Kiddush sponsorships
    func startListeningToSponsorships() {
        sponsorshipsListener?.remove()
        
        sponsorshipsListener = db.collection(scrapedKiddushCollection)
            .whereField("status", isEqualTo: "reserved")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to scraped Kiddush calendar: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.kiddushSponsorships = documents.compactMap { doc -> KiddushSponsorship? in
                    let data = doc.data()
                    return self.mapScrapedCalendarDocToSponsorship(docId: doc.documentID, data: data)
                }.sorted { $0.date < $1.date }

                print("✅ Loaded \(self.kiddushSponsorships.count) reserved dates from scraped Kiddush calendar")
            }
    }
    
    // Stop listening to sponsorships
    func stopListeningToSponsorships() {
        sponsorshipsListener?.remove()
        sponsorshipsListener = nil
    }
    
    // Fetch all Kiddush sponsorships
    func fetchKiddushSponsorships() async {
        do {
            let snapshot = try await db.collection(scrapedKiddushCollection)
                .whereField("status", isEqualTo: "reserved")
                .getDocuments()
            
            kiddushSponsorships = snapshot.documents.compactMap { doc -> KiddushSponsorship? in
                let data = doc.data()
                return mapScrapedCalendarDocToSponsorship(docId: doc.documentID, data: data)
            }.sorted { $0.date < $1.date }
        } catch {
            print("Error fetching sponsorships: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    private func parseCommunityOccasion(docId: String, data: [String: Any]) -> CommunityOccasionItem? {
        let categoryRaw = (data["categoryKey"] as? String) ?? ""
        guard let category = CommunityOccasionCategory(rawValue: categoryRaw) else {
            return nil
        }

        let groupRaw = (data["group"] as? String) ?? ""
        guard let group = CommunityOccasionGroup(rawValue: groupRaw) else {
            return nil
        }

        let rawText = (data["rawText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawText.isEmpty else {
            return nil
        }

        let normalizedCategoryLabel =
            (data["categoryLabel"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let categoryLabel = normalizedCategoryLabel.isEmpty ? category.displayLabel : normalizedCategoryLabel

        let effectiveDateIso = (data["effectiveDateIso"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceDateText = (data["sourceDateText"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = (data["source"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "website"
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        let isInPriorityWindow = data["isInPriorityWindow"] as? Bool ?? false
        let sortRank = parseIntValue(data["sortRank"])

        return CommunityOccasionItem(
            id: (data["id"] as? String) ?? docId,
            category: category,
            categoryLabel: categoryLabel,
            rawText: rawText,
            effectiveDateIso: effectiveDateIso?.isEmpty == true ? nil : effectiveDateIso,
            sourceDateText: sourceDateText?.isEmpty == true ? nil : sourceDateText,
            group: group,
            isInPriorityWindow: isInPriorityWindow,
            sortRank: sortRank,
            source: source,
            updatedAt: updatedAt
        )
    }

    func startListeningToCommunityOccasions() {
        communityOccasionsListener?.remove()

        communityOccasionsListener = db.collection(communityOccasionsCollection)
            .order(by: "sortRank")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Error listening to community occasions: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.communityOccasions = documents.compactMap { doc in
                    self.parseCommunityOccasion(docId: doc.documentID, data: doc.data())
                }.sorted {
                    if $0.sortRank != $1.sortRank {
                        return $0.sortRank < $1.sortRank
                    }
                    return $0.rawText < $1.rawText
                }

                print("✅ Loaded \(self.communityOccasions.count) community occasions")
            }
    }

    func stopListeningToCommunityOccasions() {
        communityOccasionsListener?.remove()
        communityOccasionsListener = nil
    }

    func fetchCommunityOccasions() async {
        do {
            let snapshot = try await db.collection(communityOccasionsCollection)
                .order(by: "sortRank")
                .getDocuments()

            communityOccasions = snapshot.documents.compactMap { doc in
                parseCommunityOccasion(docId: doc.documentID, data: doc.data())
            }.sorted {
                if $0.sortRank != $1.sortRank {
                    return $0.sortRank < $1.sortRank
                }
                return $0.rawText < $1.rawText
            }
        } catch {
            print("❌ Error fetching community occasions: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    // Sponsor Kiddush - returns true if successful, false if date already taken
    func sponsorKiddush(_ sponsorship: KiddushSponsorship) async -> Bool {
        // CRITICAL: Always use startOfDay for consistent date comparison
        let calendar = Calendar.chicago
        let startOfDay = calendar.startOfDay(for: sponsorship.date)
        
        // Create a deterministic document ID based on the date to ensure uniqueness
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "America/Chicago")
        let dateString = dateFormatter.string(from: startOfDay)
        let documentId = "sponsorship_\(dateString)"
        
        let sponsorshipRef = db.collection("kiddush_sponsorships").document(documentId)
        
        do {
            print("🔍 Attempting to sponsor date: \(startOfDay) with Doc ID: \(documentId)")
            
            let _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                let sponsorshipDoc: DocumentSnapshot
                do {
                    sponsorshipDoc = try transaction.getDocument(sponsorshipRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                // Check if document already exists
                if sponsorshipDoc.exists {
                    let error = NSError(domain: "AppError", code: 409, userInfo: [NSLocalizedDescriptionKey: "This Shabbat date has already been sponsored."])
                    errorPointer?.pointee = error
                    return nil
                }
                
                // Also check for legacy UUID-based documents for this date (backward compatibility)
                // Note: We can't easily query inside a transaction for other docs, 
                // but the new system will prevent NEW duplicates. 
                // Existing duplicates would be rare and handled by the UI check previously.
                
                // Create the sponsorship data
                let sponsorshipData: [String: Any] = [
                    "id": sponsorship.id.uuidString,
                    "date": Timestamp(date: startOfDay),
                    "sponsorName": sponsorship.sponsorName,
                    "sponsorEmail": sponsorship.sponsorEmail,
                    "occasion": sponsorship.occasion,
                    "tierName": sponsorship.tierName,
                    "tierAmount": sponsorship.tierAmount,
                    "isAnonymous": sponsorship.isAnonymous,
                    "timestamp": Timestamp(date: sponsorship.timestamp),
                    "isPaid": sponsorship.isPaid
                ]
                
                // Create the document
                transaction.setData(sponsorshipData, forDocument: sponsorshipRef)
                
                return nil
            })
            
            print("🎉 Sponsorship created successfully")
            return true
        } catch {
            print("❌ Error sponsoring Kiddush: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // Check if a date is available for sponsorship
    func isDateAvailable(_ date: Date) async -> Bool {
        do {
            let calendar = Calendar.chicago
            let startOfDay = calendar.startOfDay(for: date)
            let formatter = chicagoIsoFormatter()
            let docId = formatter.string(from: startOfDay)

            let snapshot = try await db.collection(scrapedKiddushCollection).document(docId).getDocument()
            guard let data = snapshot.data() else {
                return false
            }

            let status = (data["status"] as? String ?? "").lowercased()
            return status == "available"
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
                let tierName = data["tierName"] as? String ?? "Gold Kiddush"
                let tierAmount = decodeTierAmount(from: data)
                
                return KiddushSponsorship(
                    id: id,
                    date: date,
                    sponsorName: sponsorName,
                    sponsorEmail: sponsorEmail,
                    occasion: occasion,
                    tierName: tierName,
                    tierAmount: tierAmount,
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
        guard let currentUser = currentUser else { return }
        
        do {
            let snapshot = try await db.collection("kiddush_sponsorships").getDocuments()
            print("🗑️ Deleting sponsorships...")
            
            for doc in snapshot.documents {
                let data = doc.data()
                let sponsorEmail = data["sponsorEmail"] as? String
                
                // Only delete if admin OR if it's my own sponsorship
                if currentUser.isAdmin || sponsorEmail == currentUser.email {
                    try await doc.reference.delete()
                    print("   ✅ Deleted: \(doc.documentID)")
                } else {
                    print("   ⚠️ Skipped (not owner): \(doc.documentID)")
                }
            }
            
            print("✅ Finished deleting sponsorships")
        } catch {
            print("❌ Error deleting sponsorships: \(error.localizedDescription)")
        }
    }
    
    // Delete a specific sponsorship by date
    func deleteSponsorshipByDate(_ date: Date) async -> Bool {
        do {
            let calendar = Calendar.chicago
            let startOfDay = calendar.startOfDay(for: date)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "America/Chicago")
            let docId = "sponsorship_\(formatter.string(from: startOfDay))"

            let ref = db.collection("kiddush_sponsorships").document(docId)
            let doc = try await ref.getDocument()

            if doc.exists {
                try await ref.delete()
                print("✅ Deleted sponsorship: \(docId)")
                return true
            }

            // Fallback for legacy docs with non-deterministic IDs.
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                errorMessage = "Failed to compute sponsorship date range."
                return false
            }
            let snapshot = try await db.collection("kiddush_sponsorships")
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("date", isLessThan: Timestamp(date: endOfDay))
                .getDocuments()

            print("🗑️ Found \(snapshot.documents.count) fallback sponsorship(s) for \(startOfDay)")
            for fallbackDoc in snapshot.documents {
                try await fallbackDoc.reference.delete()
                print("   ✅ Deleted sponsorship: \(fallbackDoc.documentID)")
            }

            return !snapshot.documents.isEmpty
        } catch {
            print("❌ Error deleting sponsorship: \(error.localizedDescription)")
            errorMessage = "Failed to delete sponsorship: \(error.localizedDescription)"
            return false
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
            
            let allPosts = documents.compactMap { self.parseSocialPost(from: $0.data()) }
            let topLevelPosts = allPosts.filter { $0.parentPostId == nil }
            let sorted = self.sortTopLevelSocialPosts(topLevelPosts, sortBy: sortBy)
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.socialPosts = sorted
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
            let allPosts = snapshot.documents.compactMap { parseSocialPost(from: $0.data()) }
            let topLevelPosts = allPosts.filter { $0.parentPostId == nil }
            
            socialPosts = sortTopLevelSocialPosts(topLevelPosts, sortBy: sortBy)
            print("✅ Fetched \(socialPosts.count) social posts")
        } catch {
            print("❌ Error fetching social posts: \(error.localizedDescription)")
            errorMessage = "Failed to fetch posts: \(error.localizedDescription)"
        }
    }
    
    // Create a new social post
    func createSocialPost(content: String, author: User, mediaUploads: [SocialPostMediaUpload] = []) async -> Bool {
        guard content.count <= 140 else {
            errorMessage = "Post must be 140 characters or less"
            return false
        }
        guard mediaUploads.count <= 4 else {
            errorMessage = "You can attach up to 4 images."
            return false
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty || !mediaUploads.isEmpty else {
            errorMessage = "Post must include text or at least one image."
            return false
        }
        
        do {
            let post = SocialPost(
                authorName: author.name,
                authorEmail: author.email,
                content: trimmedContent
            )
            
            let uploadedMediaItems: [SocialPostMedia]
            if mediaUploads.isEmpty {
                uploadedMediaItems = []
            } else {
                uploadedMediaItems = try await uploadSocialPostMediaItems(
                    postId: post.id,
                    authorEmail: author.email,
                    mediaUploads: mediaUploads
                )
            }
            
            var postData: [String: Any] = [
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
            ]
            postData["mediaItems"] = uploadedMediaItems.map(socialMediaToMap(_:))
            postData["media"] = uploadedMediaItems.first.map(socialMediaToMap(_:)) ?? NSNull()
            
            do {
                try await db.collection("social_posts").document(post.id).setData(postData)
            } catch {
                for mediaPath in uploadedMediaItems.map(\.storagePath) {
                    try? await deleteSocialPostMedia(at: mediaPath)
                }
                throw error
            }
            
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
        
        do {
            let doc = try await db.collection("social_posts").document(postId).getDocument()
            guard let existingData = doc.data() else {
                errorMessage = "Post not found"
                return false
            }
            
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedContent.isEmpty && !hasSocialMedia(in: existingData) {
                errorMessage = "Post must include text or at least one image."
                return false
            }
            
            try await db.collection("social_posts").document(postId).updateData([
                "content": trimmedContent,
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
    func toggleLike(postId: String, userEmail: String) async -> Bool {
        do {
            let postRef = db.collection("social_posts").document(postId)
            let _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                let postDoc: DocumentSnapshot
                do {
                    postDoc = try transaction.getDocument(postRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                guard let data = postDoc.data(),
                      let likes = data["likes"] as? [String] else {
                    let error = NSError(
                        domain: "AppError",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Post not found"]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                var likeSet = Set(likes)
                if likeSet.contains(userEmail) {
                    likeSet.remove(userEmail)
                } else {
                    likeSet.insert(userEmail)
                }

                let normalizedLikes = Array(likeSet).sorted()
                transaction.updateData([
                    "likes": normalizedLikes,
                    "likeCount": normalizedLikes.count
                ], forDocument: postRef)

                return nil
            })
            
            print("✅ Toggled like for post: \(postId)")
            return true
        } catch {
            print("❌ Error toggling like: \(error.localizedDescription)")
            errorMessage = "Failed to like post: \(error.localizedDescription)"
            return false
        }
    }
    
    // Create a reply to a post
    func createReply(parentPostId: String, content: String, author: User, mediaUpload: SocialPostMediaUpload? = nil) async -> Bool {
        guard content.count <= 140 else {
            errorMessage = "Reply must be 140 characters or less"
            return false
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            errorMessage = "Reply cannot be empty"
            return false
        }
        
        do {
            let reply = SocialPost(
                authorName: author.name,
                authorEmail: author.email,
                content: trimmedContent,
                parentPostId: parentPostId
            )
            
            let parentRef = db.collection("social_posts").document(parentPostId)
            let parentDoc = try await parentRef.getDocument()
            
            guard parentDoc.exists else {
                errorMessage = "Parent post not found"
                return false
            }
            
            var uploadedMedia: SocialPostMedia?
            if let mediaUpload {
                uploadedMedia = try await uploadSocialPostMedia(
                    postId: reply.id,
                    authorEmail: author.email,
                    mediaUpload: mediaUpload,
                    mediaIndex: 0
                )
            }
            
            let replyRef = db.collection("social_posts").document(reply.id)
            
            var replyData: [String: Any] = [
                "id": reply.id,
                "authorName": reply.authorName,
                "authorEmail": reply.authorEmail,
                "content": reply.content,
                "timestamp": Timestamp(date: reply.timestamp),
                "likes": [],
                "likeCount": 0,
                "replyCount": 0,
                "parentPostId": parentPostId,
                "editedAt": NSNull()
            ]
            let replyMediaItems = uploadedMedia.map { [$0] } ?? []
            replyData["mediaItems"] = replyMediaItems.map(socialMediaToMap(_:))
            replyData["media"] = replyMediaItems.first.map(socialMediaToMap(_:)) ?? NSNull()
            
            do {
                try await replyRef.setData(replyData)
            } catch {
                if let mediaPath = uploadedMedia?.storagePath {
                    try? await deleteSocialPostMedia(at: mediaPath)
                }
                throw error
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
            
            let replies = snapshot.documents.compactMap { parseSocialPost(from: $0.data()) }
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
            let postRef = db.collection("social_posts").document(postId)
            let postDoc = try await postRef.getDocument()
            guard postDoc.exists else {
                errorMessage = "Post not found"
                return false
            }

            // The backend onDelete trigger performs authoritative cascade cleanup:
            // replyCount maintenance, reply deletion, and media deletion.
            try await postRef.delete()
            
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
            
            let mediaPaths = Set(snapshot.documents.flatMap { extractSocialMediaPaths(from: $0.data()) })
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
                print("   ✅ Deleted: \(doc.documentID)")
            }
            
            for mediaPath in mediaPaths {
                try? await deleteSocialPostMedia(at: mediaPath)
            }
            
            print("✅ All social posts deleted")
            return true
        } catch {
            print("❌ Error deleting social posts: \(error.localizedDescription)")
            errorMessage = "Failed to delete social posts: \(error.localizedDescription)"
            return false
        }
    }
    
    private func sortTopLevelSocialPosts(_ posts: [SocialPost], sortBy: SocialPostSortOption) -> [SocialPost] {
        if sortBy == .newest {
            let adminPosts = posts.filter { adminEmails.contains($0.authorEmail) }
            let regularPosts = posts.filter { !adminEmails.contains($0.authorEmail) }
            let sortedAdminPosts = adminPosts.sorted { $0.timestamp > $1.timestamp }
            let sortedRegularPosts = regularPosts.sorted { $0.timestamp > $1.timestamp }
            return sortedAdminPosts + sortedRegularPosts
        }
        
        return posts.sorted {
            if $0.likeCount != $1.likeCount {
                return $0.likeCount > $1.likeCount
            }
            return $0.timestamp > $1.timestamp
        }
    }
    
    private func parseSocialPost(from data: [String: Any]) -> SocialPost? {
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
        let mediaItems = parseSocialMediaItems(from: data["mediaItems"])
        let effectiveMediaItems: [SocialPostMedia]
        if !mediaItems.isEmpty {
            effectiveMediaItems = mediaItems
        } else if let legacyMedia = parseSocialMedia(from: data["media"]) {
            effectiveMediaItems = [legacyMedia]
        } else {
            effectiveMediaItems = []
        }
        
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
            editedAt: editedAt,
            mediaItems: effectiveMediaItems
        )
    }
    
    private func parseSocialMedia(from rawValue: Any?) -> SocialPostMedia? {
        guard let mediaMap = rawValue as? [String: Any] else {
            return nil
        }
        return parseSocialMediaMap(mediaMap)
    }
    
    private func parseSocialMediaItems(from rawValue: Any?) -> [SocialPostMedia] {
        guard let rawItems = rawValue as? [Any] else {
            return []
        }
        return rawItems.compactMap { item in
            guard let mediaMap = item as? [String: Any] else {
                return nil
            }
            return parseSocialMediaMap(mediaMap)
        }
    }
    
    private func parseSocialMediaMap(_ mediaMap: [String: Any]) -> SocialPostMedia? {
        guard let storagePath = mediaMap["storagePath"] as? String,
              let downloadURL = mediaMap["downloadURL"] as? String else {
            return nil
        }
        
        let width = parseIntValue(mediaMap["width"])
        let height = parseIntValue(mediaMap["height"])
        guard width > 0, height > 0 else {
            return nil
        }
        
        let type = mediaMap["type"] as? String ?? "image"
        let fileSizeBytes = parseIntValue(mediaMap["fileSizeBytes"])
        
        return SocialPostMedia(
            type: type,
            storagePath: storagePath,
            downloadURL: downloadURL,
            width: width,
            height: height,
            fileSizeBytes: fileSizeBytes
        )
    }
    
    private func socialMediaToMap(_ media: SocialPostMedia) -> [String: Any] {
        [
            "type": media.type,
            "storagePath": media.storagePath,
            "downloadURL": media.downloadURL,
            "width": media.width,
            "height": media.height,
            "fileSizeBytes": media.fileSizeBytes
        ]
    }
    
    private func parseIntValue(_ value: Any?) -> Int {
        if let intValue = value as? Int {
            return intValue
        }
        if let int64Value = value as? Int64 {
            return Int(int64Value)
        }
        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        if let numberValue = value as? NSNumber {
            return numberValue.intValue
        }
        return 0
    }
    
    private func hasSocialMedia(in data: [String: Any]) -> Bool {
        !extractSocialMediaPaths(from: data).isEmpty
    }
    
    private func uploadSocialPostMedia(
        postId: String,
        authorEmail: String,
        mediaUpload: SocialPostMediaUpload,
        mediaIndex: Int
    ) async throws -> SocialPostMedia {
        let storagePath = "social_posts/\(postId)/image_\(mediaIndex + 1).jpg"
        let mediaRef = storage.reference(withPath: storagePath)
        
        let metadata = StorageMetadata()
        metadata.contentType = mediaUpload.contentType
        metadata.customMetadata = [
            "authorEmail": authorEmail,
            "postId": postId,
            "mediaIndex": String(mediaIndex)
        ]
        
        let uploadedMetadata = try await mediaRef.putDataAsync(mediaUpload.data, metadata: metadata)
        let downloadURL = try await mediaRef.downloadURL()
        
        return SocialPostMedia(
            type: "image",
            storagePath: storagePath,
            downloadURL: downloadURL.absoluteString,
            width: mediaUpload.width,
            height: mediaUpload.height,
            fileSizeBytes: Int(uploadedMetadata.size)
        )
    }
    
    private func uploadSocialPostMediaItems(
        postId: String,
        authorEmail: String,
        mediaUploads: [SocialPostMediaUpload]
    ) async throws -> [SocialPostMedia] {
        var uploadedItems: [SocialPostMedia] = []
        uploadedItems.reserveCapacity(mediaUploads.count)
        
        for (index, mediaUpload) in mediaUploads.enumerated() {
            do {
                let uploaded = try await uploadSocialPostMedia(
                    postId: postId,
                    authorEmail: authorEmail,
                    mediaUpload: mediaUpload,
                    mediaIndex: index
                )
                uploadedItems.append(uploaded)
            } catch {
                for uploaded in uploadedItems {
                    try? await deleteSocialPostMedia(at: uploaded.storagePath)
                }
                throw error
            }
        }
        
        return uploadedItems
    }
    
    private func deleteSocialPostMedia(at storagePath: String) async throws {
        guard !storagePath.isEmpty else { return }
        try await storage.reference(withPath: storagePath).delete()
    }
    
    private func extractSocialMediaPaths(from data: [String: Any]) -> Set<String> {
        var paths = Set<String>()
        
        if let mediaItems = data["mediaItems"] as? [Any] {
            for item in mediaItems {
                guard let mediaMap = item as? [String: Any] else { continue }
                if let path = mediaMap["storagePath"] as? String, !path.isEmpty {
                    paths.insert(path)
                }
            }
        }
        
        if let mediaMap = data["media"] as? [String: Any],
           let legacyPath = mediaMap["storagePath"] as? String,
           !legacyPath.isEmpty {
            paths.insert(legacyPath)
        }
        
        return paths
    }
    
    // MARK: - User Management
    
    // Create or update user document in Firestore
    func createOrUpdateUser(user: User) async -> Bool {
        do {
            let userRef = db.collection("users").document(user.email)
            // Create data dict
            var userData: [String: Any] = [
                "name": user.name,
                "email": user.email,
                "totalPledged": user.totalPledged,
                "lastUpdated": Timestamp(date: Date())
            ]
            
            // Only set isAdmin if it's the super admin or if we are creating a new user (default false)
            // But since we use merge: true, omitting it is safer for existing users.
            // Exception: If it's the super admin, force true.
            if user.email.lowercased() == "admin@knb.com" {
                userData["isAdmin"] = true
            }
            
            try await userRef.setData(userData, merge: true)
            
            print("✅ User document synced: \(user.email)")
            self.currentUser = user
            return true
        } catch {
            print("❌ Error syncing user: \(error.localizedDescription)")
            errorMessage = "Failed to sync user data: \(error.localizedDescription)"
            return false
        }
    }
    
    // Fetch user data from Firestore
    func fetchUser(email: String) async -> User? {
        do {
            let userDoc = try await db.collection("users").document(email).getDocument()
            
            guard let data = userDoc.data() else {
                return nil
            }

            let name = data["name"] as? String ?? "Member"
            let totalPledged = data["totalPledged"] as? Double ?? 0
            let isAdmin = data["isAdmin"] as? Bool ?? false

            return User(
                name: name,
                email: email,
                totalPledged: totalPledged,
                isAdmin: isAdmin,
                notificationPrefs: NotificationPreferences(data: data["notificationPrefs"] as? [String: Any] ?? [:])
            )
        } catch {
            print("❌ Error fetching user data: \(error.localizedDescription)")
            return nil
        }
    }

    // Fetch and set current user data from Firestore.
    func fetchUserData(email: String) async -> User? {
        guard let user = await fetchUser(email: email) else {
            return nil
        }

        self.currentUser = user
        startListeningToUser(email: email)
        return user
    }
    
    // Listen for real-time updates to the current user's profile
    private var userListener: ListenerRegistration?
    
    func startListeningToUser(email: String) {
        // Remove existing listener if any
        userListener?.remove()
        
        print("👂 Starting real-time listener for user: \(email)")
        
        userListener = db.collection("users").document(email)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let error = error {
                        print("❌ Error listening to user updates: \(error.localizedDescription)")
                        return
                    }

                    guard let snapshot = snapshot, let data = snapshot.data() else {
                        print("⚠️ User document does not exist")
                        return
                    }

                    // Parse updated user data
                    let name = data["name"] as? String ?? "Member"
                    let totalPledged = data["totalPledged"] as? Double ?? 0
                    let isAdmin = data["isAdmin"] as? Bool ?? false

                    let updatedUser = User(
                        name: name,
                        email: email,
                        totalPledged: totalPledged,
                        isAdmin: isAdmin,
                        notificationPrefs: NotificationPreferences(data: data["notificationPrefs"] as? [String: Any] ?? [:])
                    )

                    // Only update if something changed to avoid loops
                    if self.currentUser?.isAdmin != updatedUser.isAdmin ||
                        self.currentUser?.name != updatedUser.name ||
                        self.currentUser?.totalPledged != updatedUser.totalPledged {
                        print("🔄 User profile updated from Firestore. Admin: \(isAdmin)")
                        self.currentUser = updatedUser

                        if isAdmin {
                            self.adminEmails.insert(email)
                        } else {
                            self.adminEmails.remove(email)
                        }
                    }
                }
            }
    }
    
    func stopListeningToUser() {
        userListener?.remove()
        userListener = nil
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

    // Atomically increment total pledged to avoid lost updates from concurrent bids.
    func incrementUserTotalPledged(email: String, by amount: Double) async -> Bool {
        guard amount > 0, amount.isFinite else {
            errorMessage = "Invalid total pledged increment."
            return false
        }

        do {
            let userRef = db.collection("users").document(email)
            try await userRef.updateData([
                "totalPledged": FieldValue.increment(amount),
                "lastUpdated": Timestamp(date: Date())
            ])

            if currentUser?.email == email {
                currentUser?.totalPledged += amount
            }

            print("✅ Incremented totalPledged for \(email) by $\(amount)")
            return true
        } catch {
            print("❌ Error incrementing totalPledged: \(error.localizedDescription)")
            errorMessage = "Failed to update total pledged: \(error.localizedDescription)"
            return false
        }
    }
    
    // Update user's name
    func updateUserName(email: String, newName: String) async -> Bool {
        // Validate name
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty"
            return false
        }
        
        guard trimmedName.count >= 3 else {
            errorMessage = "Name must be at least 3 characters"
            return false
        }
        
        guard trimmedName.count <= 50 else {
            errorMessage = "Name must be 50 characters or less"
            return false
        }
        
        do {
            let userRef = db.collection("users").document(email)
            try await userRef.updateData([
                "name": trimmedName,
                "lastUpdated": Timestamp(date: Date())
            ])
            
            print("✅ Updated name for \(email): \(trimmedName)")
            return true
        } catch {
            print("❌ Error updating name: \(error.localizedDescription)")
            errorMessage = "Failed to update name: \(error.localizedDescription)"
            return false
        }
    }
    
    

    
    // Update notification preferences
    func updateNotificationPreferences(prefs: NotificationPreferences, userEmail: String) async -> Bool {
        do {
            try await db.collection("users").document(userEmail).updateData([
                "notificationPrefs": try Firestore.Encoder().encode(prefs)
            ])
            
            // Update local user state
            await MainActor.run {
                if self.currentUser?.email == userEmail {
                    self.currentUser?.notificationPrefs = prefs
                }
            }
            
            print("✅ Notification preferences updated for \(userEmail)")
            return true
        } catch {
            print("❌ Error updating notification preferences: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Admin User Management
    
    // Fetch all admins and update local cache
    func fetchAdmins() async {
        do {
            let snapshot = try await db.collection("users")
                .whereField("isAdmin", isEqualTo: true)
                .getDocuments()
            
            let admins = snapshot.documents.map { $0.documentID } // email is document ID
            
            await MainActor.run {
                // Always keep super admin
                var newSet = Set(admins)
                newSet.insert("admin@knb.com")
                self.adminEmails = newSet
            }
            
            print("✅ Fetched \(admins.count) admins")
        } catch {
            print("❌ Error fetching admins: \(error.localizedDescription)")
        }
    }
    
    // Fetch all users (Admin only)
    func fetchAllUsers() async -> [User] {
        do {
            let snapshot = try await db.collection("users")
                .order(by: "name")
                .getDocuments()
            
            let users = snapshot.documents.compactMap { doc -> User? in
                let data = doc.data()
                let email = doc.documentID
                
                let name = data["name"] as? String ?? "Member"
                let totalPledged = data["totalPledged"] as? Double ?? 0
                let isAdmin = data["isAdmin"] as? Bool ?? false
                
                return User(
                    name: name,
                    email: email,
                    totalPledged: totalPledged,
                    isAdmin: isAdmin,
                    notificationPrefs: NotificationPreferences(data: data["notificationPrefs"] as? [String: Any] ?? [:])
                )
            }
            
            print("✅ Fetched \(users.count) users")
            return users
        } catch {
            print("❌ Error fetching all users: \(error.localizedDescription)")
            return []
        }
    }
    
    // Update user admin status (Super Admin only)
    func updateUserAdminStatus(email: String, isAdmin: Bool) async -> Bool {
        do {
            try await db.collection("users").document(email).updateData([
                "isAdmin": isAdmin,
                "lastUpdated": Timestamp(date: Date())
            ])
            
            print("✅ Updated admin status for \(email) to \(isAdmin)")
            return true
        } catch {
            print("❌ Error updating admin status: \(error.localizedDescription)")
            errorMessage = "Failed to update admin status: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Seat Reservations
    
    // Start listening to seat reservations with real-time updates
    func startListeningToSeatReservations() {
        seatReservationsListener?.remove()
        
        seatReservationsListener = db.collection("seat_reservations")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to seat reservations: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.seatReservations = documents.compactMap { doc -> SeatReservation? in
                    let data = doc.data()
                    
                    guard let id = data["id"] as? String,
                          let row = data["row"] as? String,
                          let number = data["number"] as? Int,
                          let reservedBy = data["reservedBy"] as? String,
                          let reservedByName = data["reservedByName"] as? String,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                        return nil
                    }
                    
                    return SeatReservation(
                        id: id,
                        row: row,
                        number: number,
                        reservedBy: reservedBy,
                        reservedByName: reservedByName,
                        timestamp: timestamp
                    )
                }
            }
    }
    
    // Stop listening to seat reservations
    func stopListeningToSeatReservations() {
        seatReservationsListener?.remove()
        seatReservationsListener = nil
    }
    
    // Reserve a seat (with transaction to prevent conflicts)
    func reserveSeat(row: String, number: Int, userEmail: String, userName: String) async -> Bool {
        // Create unique document ID based on row and number
        let seatId = "\(row)-\(number)"
        let seatRef = db.collection("seat_reservations").document(seatId)
        
        do {
            let _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                let seatDoc: DocumentSnapshot
                do {
                    seatDoc = try transaction.getDocument(seatRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                // Check if seat is already reserved
                if seatDoc.exists {
                    let error = NSError(domain: "AppError", code: 409, userInfo: [NSLocalizedDescriptionKey: "This seat is already reserved"])
                    errorPointer?.pointee = error
                    return nil
                }
                
                // Create the reservation
                let reservationData: [String: Any] = [
                    "id": seatId,
                    "row": row,
                    "number": number,
                    "reservedBy": userEmail,
                    "reservedByName": userName,
                    "timestamp": Timestamp(date: Date())
                ]
                
                transaction.setData(reservationData, forDocument: seatRef)
                
                return nil
            })
            
            print("✅ Seat \(row)\(number) reserved successfully")
            return true
        } catch {
            print("❌ Error reserving seat: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // Cancel a seat reservation (only by the person who reserved it or admin)
    func cancelSeatReservation(row: String, number: Int, userEmail: String) async -> Bool {
        let seatId = "\(row)-\(number)"
        let seatRef = db.collection("seat_reservations").document(seatId)
        
        do {
            let seatDoc = try await seatRef.getDocument()
            
            guard seatDoc.exists,
                  let data = seatDoc.data(),
                  let reservedBy = data["reservedBy"] as? String else {
                errorMessage = "Seat reservation not found"
                return false
            }
            
            // Check if user is admin or the person who reserved it
            guard let currentUser = currentUser,
                  (currentUser.isAdmin || reservedBy == userEmail) else {
                errorMessage = "You can only cancel your own reservations"
                return false
            }
            
            try await seatRef.delete()
            print("✅ Seat \(row)\(number) reservation cancelled")
            return true
        } catch {
            print("❌ Error cancelling seat reservation: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // Get reservation for a specific seat
    func getSeatReservation(row: String, number: Int) -> SeatReservation? {
        return seatReservations.first { $0.row == row && $0.number == number }
    }
    
    // Get all reservations for a user
    func getUserSeatReservations(userEmail: String) -> [SeatReservation] {
        return seatReservations.filter { $0.reservedBy == userEmail }
    }
}
