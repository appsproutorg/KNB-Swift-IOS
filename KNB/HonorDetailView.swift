//
//  HonorDetailView.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import SwiftUI

struct HonorDetailView: View {
    let honor: Honor
    @Binding var currentUser: User?
    @ObservedObject var firestoreManager: FirestoreManager
    @Environment(\.dismiss) var dismiss
    
    @State private var bidAmount: String = ""
    @State private var comment: String = ""
    @State private var showingBidConfirmation = false
    @State private var showingBuyNowConfirmation = false
    @State private var enableAutoBid = false
    @State private var showingBidHistory = false
    @State private var showingInvalidBidAlert = false
    @State private var invalidBidMessage = ""
    
    // Maximum allowed bid amount (1 million dollars)
    private let maxBidAmount: Double = 1_000_000
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        HonorHeaderView(honor: honor)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Current winning info
                        if !honor.isSold {
                            CurrentBidInfo(honor: honor)
                                .padding(.horizontal)
                        }
                        
                        // Bid section
                        if !honor.isSold {
                            BidSection(
                                bidAmount: $bidAmount,
                                comment: $comment,
                                enableAutoBid: $enableAutoBid,
                                onPlaceBid: placeBid,
                                onBuyNow: buyNow,
                                onShowHistory: { showingBidHistory = true },
                                buyNowPrice: honor.buyNowPrice
                            )
                            .padding(.horizontal)
                        } else {
                            SoldBanner(winner: honor.currentWinner ?? "Unknown", amount: honor.currentBid)
                                .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle(honor.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Confirm Bid", isPresented: $showingBidConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Place Bid") {
                    confirmBid()
                }
            } message: {
                Text("Place a bid of $\(bidAmount)?")
            }
            .alert("Confirm Purchase", isPresented: $showingBuyNowConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Buy Now") {
                    confirmBuyNow()
                }
            } message: {
                Text("Purchase this honor for $\(honor.buyNowPrice.toSafeInt())?")
            }
            .alert("Invalid Bid", isPresented: $showingInvalidBidAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(invalidBidMessage)
            }
            .sheet(isPresented: $showingBidHistory) {
                BidHistoryView(bids: honor.bids)
            }
        }
    }
    
    private func placeBid() {
        // Validate bid amount is a valid number
        guard let amount = Double(bidAmount) else {
            invalidBidMessage = "Please enter a valid bid amount"
            showingInvalidBidAlert = true
            return
        }
        
        // Check if bid is higher than current bid
        guard amount > honor.currentBid else {
            invalidBidMessage = "Your bid must be higher than the current bid of $\(honor.currentBid.toSafeInt())"
            showingInvalidBidAlert = true
            return
        }
        
        // Check if bid is less than or equal to max allowed
        guard amount <= maxBidAmount else {
            invalidBidMessage = "Bid amount cannot exceed $\(maxBidAmount.toSafeInt()). Please enter a reasonable amount."
            showingInvalidBidAlert = true
            return
        }
        
        // Check if bid is a reasonable positive number
        guard amount > 0 && !amount.isNaN && !amount.isInfinite else {
            invalidBidMessage = "Please enter a valid bid amount"
            showingInvalidBidAlert = true
            return
        }
        
        showingBidConfirmation = true
    }
    
    private func confirmBid() {
        guard let amount = Double(bidAmount),
              let user = currentUser else { return }
        
        // Extra safety check before confirming
        guard amount > 0 && amount <= maxBidAmount && !amount.isNaN && !amount.isInfinite else {
            invalidBidMessage = "Invalid bid amount"
            showingInvalidBidAlert = true
            return
        }
        
        let newBid = Bid(
            amount: amount,
            bidderName: user.name,
            comment: comment.isEmpty ? nil : comment
        )
        
        Task {
            let success = await firestoreManager.placeBid(honorId: honor.id, bid: newBid)
            
            if success {
                // Success feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                bidAmount = ""
                comment = ""
                
                // Update user's total pledged (you can later sync this to Firestore too)
                currentUser?.totalPledged += amount
            }
        }
    }
    
    private func buyNow() {
        showingBuyNowConfirmation = true
    }
    
    private func confirmBuyNow() {
        guard let user = currentUser else { return }
        
        let buyNowBid = Bid(
            amount: honor.buyNowPrice,
            bidderName: user.name,
            comment: "Buy Now Purchase"
        )
        
        Task {
            let success = await firestoreManager.buyNow(honorId: honor.id, bid: buyNowBid)
            
            if success {
                // Success feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
                
                // Update user's total pledged
                currentUser?.totalPledged += honor.buyNowPrice
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Honor Header View
struct HonorHeaderView: View {
    let honor: Honor
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "scroll.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .padding()
                .background(
                    Circle()
                        .fill(.blue.opacity(0.1))
                )
            
            Text(honor.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            Text(honor.description)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

// MARK: - Current Bid Info
struct CurrentBidInfo: View {
    let honor: Honor
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Current Bid")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Text("$\(honor.currentBid.toSafeInt())")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            if let winner = honor.currentWinner {
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Leading Bidder")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.orange)
                        Text(winner)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

// MARK: - Bid Section
struct BidSection: View {
    @Binding var bidAmount: String
    @Binding var comment: String
    @Binding var enableAutoBid: Bool
    let onPlaceBid: () -> Void
    let onBuyNow: () -> Void
    let onShowHistory: () -> Void
    let buyNowPrice: Double
    @State private var bidButtonPressed = false
    @State private var buyButtonPressed = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Bid input
            VStack(alignment: .leading, spacing: 10) {
                Text("My Bid")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("$")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    TextField("Enter amount", text: $bidAmount)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .keyboardType(.numberPad)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                
                Text("Maximum bid: $1,000,000")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 5)
            }
            
            // Comment
            VStack(alignment: .leading, spacing: 10) {
                Text("Comment (Optional)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                TextField("Add a comment...", text: $comment, axis: .vertical)
                    .lineLimit(3...5)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
            
            // Auto bid toggle
            Toggle(isOn: $enableAutoBid) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.yellow)
                    Text("Set automatic bidding")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            // Action buttons
            VStack(spacing: 15) {
                Button(action: onPlaceBid) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("Place Bid")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .cornerRadius(15)
                    .shadow(color: .blue.opacity(0.4), radius: bidButtonPressed ? 5 : 10, x: 0, y: bidButtonPressed ? 2 : 5)
                    .scaleEffect(bidButtonPressed ? 0.95 : 1.0)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                bidButtonPressed = true
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                bidButtonPressed = false
                            }
                        }
                )
                
                Button(action: onBuyNow) {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("Buy It Now for $\(buyNowPrice.toSafeInt())")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .cornerRadius(15)
                    .shadow(color: .green.opacity(0.4), radius: buyButtonPressed ? 5 : 10, x: 0, y: buyButtonPressed ? 2 : 5)
                    .scaleEffect(buyButtonPressed ? 0.95 : 1.0)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                buyButtonPressed = true
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                buyButtonPressed = false
                            }
                        }
                )
                
                Button(action: onShowHistory) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("View Bids History")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

// MARK: - Sold Banner
struct SoldBanner: View {
    let winner: String
    let amount: Double
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("SOLD")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
            
            VStack(spacing: 5) {
                Text("Winner: \(winner)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Text("Final Price: $\(amount.toSafeInt())")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(.green.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Bid History View
struct BidHistoryView: View {
    let bids: [Bid]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(bids) { bid in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(bid.bidderName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            
                            Spacer()
                            
                            Text("$\(bid.amount.toSafeInt())")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                        
                        Text(bid.timestamp, style: .relative)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        if let comment = bid.comment {
                            Text(comment)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.top, 5)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("Bid History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

