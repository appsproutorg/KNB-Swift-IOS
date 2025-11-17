//
//  BidHistoryView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct BidHistoryView: View {
    let bids: [Bid]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if bids.isEmpty {
                    EmptyBidHistoryView()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(bids.enumerated()), id: \.element.id) { index, bid in
                                BidHistoryRow(
                                    bid: bid,
                                    isFirst: index == 0,
                                    isLast: index == bids.count - 1
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Bid History")
            .navigationBarTitleDisplayMode(.large)
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

struct BidHistoryRow: View {
    let bid: Bid
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Top connector (hidden for first item)
                if !isFirst {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 2)
                        .frame(height: 20)
                }
                
                // Circle indicator
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
                
                // Bottom connector (hidden for last item)
                if !isLast {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)
            
            // Bid content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("$\(bid.amount.toSafeInt())")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if isFirst {
                        Text("Current")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                    }
                }
                
                Text(bid.bidderName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if let comment = bid.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                Text(timeAgoString(from: bid.timestamp))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .padding(.vertical, 4)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyBidHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gavel")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Bids Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Be the first to place a bid!")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    BidHistoryView(bids: [
        Bid(amount: 500, bidderName: "John Doe", timestamp: Date().addingTimeInterval(-3600), comment: "Great honor!"),
        Bid(amount: 400, bidderName: "Jane Smith", timestamp: Date().addingTimeInterval(-7200)),
        Bid(amount: 300, bidderName: "Bob Johnson", timestamp: Date().addingTimeInterval(-10800))
    ])
}

