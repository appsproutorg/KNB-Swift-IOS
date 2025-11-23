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
    
    var sortedBids: [Bid] {
        bids.sorted { $0.timestamp > $1.timestamp }
    }
    
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
                            ForEach(Array(sortedBids.enumerated()), id: \.element.id) { index, bid in
                                BidHistoryRow(
                                    bid: bid,
                                    isFirst: index == 0,
                                    isLast: index == sortedBids.count - 1
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
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 2)
                        .frame(height: 24)
                } else {
                    Spacer().frame(height: 24)
                }
                
                // Circle indicator
                ZStack {
                    Circle()
                        .fill(isFirst ? Color.green : Color.blue)
                        .frame(width: 14, height: 14)
                        .shadow(color: (isFirst ? Color.green : Color.blue).opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
                
                // Bottom connector (hidden for last item)
                if !isLast {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer()
                }
            }
            .frame(width: 16)
            
            // Bid content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("$\(bid.amount.toSafeInt())")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(isFirst ? .green : .primary)
                    
                    Spacer()
                    
                    if isFirst {
                        Text("Current Leader")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                    }
                }
                
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(bid.bidderName)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                if let comment = bid.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                        .padding(.leading, 8)
                        .overlay(
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 2)
                                .padding(.vertical, 2),
                            alignment: .leading
                        )
                }
                
                Text(timeAgoString(from: bid.timestamp))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isFirst ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .padding(.bottom, 16)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyBidHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Bids Yet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Be the first to place a bid!")
                .font(.system(size: 16, weight: .medium, design: .rounded))
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

