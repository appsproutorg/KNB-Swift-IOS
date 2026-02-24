//
//  SponsorshipFormView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

private enum SponsorshipTier: String, CaseIterable, Identifiable {
    case platinum
    case gold
    case silver
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .platinum: return "Platinum exclusive Kiddush"
        case .gold: return "Gold Kiddush"
        case .silver: return "Silver Kiddush (or co-sponsored Kiddush)"
        }
    }
    
    var amount: Int {
        switch self {
        case .platinum: return 700
        case .gold: return 500
        case .silver: return 360
        }
    }
    
    var subtitle: String {
        switch self {
        case .platinum: return "Exclusive full Kiddush sponsorship"
        case .gold: return "Standard full Kiddush sponsorship"
        case .silver: return "Co-sponsored Kiddush option"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .platinum: return Color(red: 0.44, green: 0.49, blue: 0.56)
        case .gold: return Color(red: 0.79, green: 0.6, blue: 0.18)
        case .silver: return Color(red: 0.3, green: 0.54, blue: 0.82)
        }
    }
}

private enum SponsorshipPalette {
    static let backgroundTop = Color(red: 0.95, green: 0.97, blue: 1.0)
    static let backgroundBottom = Color(red: 0.99, green: 0.95, blue: 0.93)
    static let cardFill = Color.white.opacity(0.62)
    static let cardStroke = Color.white.opacity(0.88)
    static let headerBlue = Color(red: 0.12, green: 0.49, blue: 0.9)
    static let headerCyan = Color(red: 0.2, green: 0.67, blue: 0.87)
}

struct SponsorshipFormView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject var firestoreManager: FirestoreManager
    
    let shabbatDate: Date
    let shabbatTime: ShabbatTime?
    let dailyCalendarDay: DailyCalendarDay?
    let currentUser: User?
    
    @State private var name: String
    @State private var email: String
    @State private var occasion: String = ""
    @State private var isAnonymous: Bool = false
    @State private var isSubmitting = false
    @State private var showingConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeletingSponsorship = false
    @State private var errorMessage: String?
    @State private var hebrewDate: String?
    @State private var existingSponsorship: KiddushSponsorship?
    @State private var didOpenPaymentLink = false
    @State private var selectedTier: SponsorshipTier = .gold
    
    private let squareCheckoutURL = "https://checkout.square.site/merchant/MLQJKX2QTSGN8/checkout/POVM2FK25UAE2G4AHUIZY6SQ"
    
    var isPastDate: Bool {
        shabbatDate < Date()
    }
    
    init(
        shabbatDate: Date,
        shabbatTime: ShabbatTime?,
        dailyCalendarDay: DailyCalendarDay? = nil,
        currentUser: User?,
        firestoreManager: FirestoreManager
    ) {
        self.shabbatDate = shabbatDate
        self.shabbatTime = shabbatTime
        self.dailyCalendarDay = dailyCalendarDay
        self.currentUser = currentUser
        self.firestoreManager = firestoreManager
        
        // Pre-fill user data
        _name = State(initialValue: currentUser?.name ?? "")
        _email = State(initialValue: currentUser?.email ?? "")
    }
    
    var isSponsoredByCurrentUser: Bool {
        guard let sponsorship = existingSponsorship, let userEmail = currentUser?.email else { return false }
        return sponsorship.sponsorEmail == userEmail
    }
    
    var sponsorDisplayText: String {
        guard let sponsorship = existingSponsorship else { return "" }
        let isAdminViewer = currentUser?.isAdmin == true
        if sponsorship.isAnonymous && !isSponsoredByCurrentUser && !isAdminViewer {
            return "Anonymous Sponsor"
        }
        if sponsorship.sponsorName == "Reserved" {
            let extracted = extractSponsorName(from: sponsorship.occasion)
            if !extracted.isEmpty {
                return extracted
            }
        }
        return sponsorship.sponsorName
    }

    private var displayedAmount: Int {
        existingSponsorship?.tierAmount ?? selectedTier.amount
    }

    private var shouldShowAmountCard: Bool {
        guard existingSponsorship != nil else { return true }
        return isSponsoredByCurrentUser
    }

    private var canAdminDeleteSponsorship: Bool {
        guard existingSponsorship != nil else { return false }
        return currentUser?.isAdmin == true
    }

    private var additionalZmanimText: String? {
        guard let zmanim = dailyCalendarDay?.zmanim else { return nil }
        var parts: [String] = []

        let fields: [(String, String?)] = [
            ("Alos", zmanim.alos),
            ("Netz", zmanim.netz),
            ("Chatzos", zmanim.chatzos),
            ("Shkia", zmanim.shkia),
            ("Tzes", zmanim.tzes),
        ]

        for (label, value) in fields {
            guard let value else { continue }
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                parts.append("\(label): \(cleaned)")
            }
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "  •  ")
    }

    private var additionalZmanimItems: [(title: String, value: String)] {
        guard let zmanim = dailyCalendarDay?.zmanim else { return [] }
        let fields: [(String, String?)] = [
            ("Alos", zmanim.alos),
            ("Netz", zmanim.netz),
            ("Chatzos", zmanim.chatzos),
            ("Shkia", zmanim.shkia),
            ("Tzes", zmanim.tzes),
        ]

        return fields.compactMap { (title, value) in
            guard let value else { return nil }
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }
            return (title, cleaned)
        }
    }

    private func extractSponsorName(from occasion: String) -> String {
        let source = occasion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return "" }

        let lower = source.lowercased()
        let prefixes = [
            "kiddush is sponsored by ",
            "kiddush is sponosored by ",
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

        guard let startOffset, startOffset < source.count else {
            return ""
        }

        let startIndex = source.index(source.startIndex, offsetBy: startOffset)
        let remaining = String(source[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if remaining.isEmpty { return "" }

        let separators = [" on occasion of ", " in honor of ", "."]
        let remainingLower = remaining.lowercased()
        var cutIndex = remaining.endIndex
        for separator in separators {
            if let range = remainingLower.range(of: separator) {
                let offset = remainingLower.distance(from: remainingLower.startIndex, to: range.lowerBound)
                let candidate = remaining.index(remaining.startIndex, offsetBy: offset)
                if candidate < cutIndex {
                    cutIndex = candidate
                }
            }
        }

        return String(remaining[..<cutIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: shabbatDate)
    }

    private var tierStorageKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/Chicago")
        return "kiddushSelectedTier_\(formatter.string(from: shabbatDate))"
    }

    @ViewBuilder
    private var shabbatHeaderSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [SponsorshipPalette.headerBlue, SponsorshipPalette.headerCyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 20)

            Text("Sponsor Kiddush")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text(formattedDate)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if let hebrewDate = hebrewDate {
                Text(hebrewDate)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            if let parsha = shabbatTime?.parsha {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 18))
                    Text("Parashat \(parsha)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(SponsorshipPalette.headerBlue)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.7))
                )
                .overlay(
                    Capsule()
                        .stroke(SponsorshipPalette.headerBlue.opacity(0.16), lineWidth: 1.2)
                )
            }

            if let shabbatTime = shabbatTime {
                HStack(spacing: 20) {
                    SponsorshipTimeCard(
                        icon: "light.max",
                        title: "Candle Lighting",
                        timeText: formatTime(shabbatTime.candleLighting),
                        accent: Color(red: 0.92, green: 0.47, blue: 0.17),
                        iconBackground: Color(red: 1.0, green: 0.95, blue: 0.86)
                    )

                    SponsorshipTimeCard(
                        icon: "moon.stars.fill",
                        title: "Havdalah",
                        timeText: formatTime(shabbatTime.havdalah),
                        accent: Color(red: 0.48, green: 0.35, blue: 0.89),
                        iconBackground: Color(red: 0.93, green: 0.91, blue: 1.0)
                    )
                }
                .padding(.horizontal)

                if !additionalZmanimItems.isEmpty {
                    VStack(spacing: 7) {
                        Text("Additional Zmanim")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                            ],
                            spacing: 8
                        ) {
                            ForEach(additionalZmanimItems, id: \.title) { item in
                                HStack(spacing: 5) {
                                    Text(item.title)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    Text(item.value)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary.opacity(0.9))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.46))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(0.88), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                } else if let additionalZmanimText {
                    Text(additionalZmanimText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.bottom, 10)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Modern glassy background with mesh gradient effect
                ZStack {
                    LinearGradient(
                        colors: [
                            SponsorshipPalette.backgroundTop,
                            SponsorshipPalette.backgroundBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Subtle overlay circles for depth
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.cyan.opacity(0.16), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 400
                            )
                        )
                        .blur(radius: 60)
                        .offset(x: -100, y: -100)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.orange.opacity(0.12), .clear],
                                center: .bottomTrailing,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .blur(radius: 50)
                        .offset(x: 100, y: 100)
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        shabbatHeaderSection
                        
                        // Past Date Warning Banner
                        if isPastDate {
                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Past Date")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(.orange)
                                        
                                        Text("This date has passed and cannot be sponsored.")
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.orange.opacity(0.1))
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                            .opacity(0.8)
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.orange.opacity(0.3), lineWidth: 1.5)
                                    }
                                )
                                .shadow(color: .orange.opacity(0.2), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Already Sponsored Banner with stronger sponsor + reason emphasis
                        if let sponsorship = existingSponsorship {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.green)
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Already Sponsored")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundStyle(.green)

                                        if isSponsoredByCurrentUser {
                                            Text("This is your sponsorship")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.blue)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(.blue.opacity(0.12))
                                                .clipShape(Capsule())
                                        }
                                    }

                                    Spacer()
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sponsored By")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    Text(sponsorDisplayText)
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    if currentUser?.isAdmin == true, let sponsorship = existingSponsorship, sponsorship.sponsorEmail != "website@heritagecongregation.com" {
                                        Text(sponsorship.sponsorEmail)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Sponsorship Reason")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    Text(sponsorship.occasion)
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineSpacing(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(16)
                                .background(.green.opacity(0.09))
                                .cornerRadius(12)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.green.opacity(0.1))
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                            .opacity(0.8)
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.green.opacity(0.3), lineWidth: 1.5)
                                    }
                                )
                                .shadow(color: .green.opacity(0.2), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal)
                        }

                        if canAdminDeleteSponsorship {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                HStack(spacing: 8) {
                                    if isDeletingSponsorship {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "trash.fill")
                                    }
                                    Text(isDeletingSponsorship ? "Deleting..." : "Delete This Sponsorship (Admin)")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .disabled(isDeletingSponsorship)
                            .padding(.horizontal)
                        }
                        
                        if shouldShowAmountCard {
                            // Price Card with modern glassy design
                            VStack(spacing: 8) {
                                Text("Sponsorship Amount")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                
                                Text("$\(displayedAmount)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(red: 0.12, green: 0.66, blue: 0.41), Color(red: 0.17, green: 0.78, blue: 0.53)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text(existingSponsorship == nil ? "Payment details will be sent via email" : "Recorded sponsorship amount")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(Color(red: 0.97, green: 1.0, blue: 0.98))
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(.white.opacity(0.5))
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.green.opacity(0.32), Color.green.opacity(0.08)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                }
                            )
                            .shadow(color: .green.opacity(0.1), radius: 15, x: 0, y: 8)
                            .padding(.horizontal)
                        }
                        
                        // Sponsorship Tier Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Choose Sponsorship Tier")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            ForEach(SponsorshipTier.allCases) { tier in
                                Button {
                                    guard existingSponsorship == nil else { return }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        selectedTier = tier
                                    }
                                    UserDefaults.standard.set(tier.rawValue, forKey: tierStorageKey)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    SponsorshipTierOptionCard(
                                        tier: tier,
                                        isSelected: (existingSponsorship?.tierAmount == tier.amount) || (existingSponsorship == nil && selectedTier == tier)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(existingSponsorship != nil)
                                .opacity(existingSponsorship != nil ? 0.7 : 1.0)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(SponsorshipPalette.cardFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(SponsorshipPalette.cardStroke, lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // Form Fields (only show if not already sponsored and not past date)
                        if (existingSponsorship == nil || isSponsoredByCurrentUser) && !isPastDate {
                        VStack(spacing: 20) {
                            // Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Your name", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(12)
                                    .autocapitalization(.words)
                            }
                            
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                
                                TextField("email@example.com", text: $email)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(12)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            
                            // Occasion Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Occasion")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Birthday, Anniversary, etc.", text: $occasion)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(12)
                                    .autocapitalization(.sentences)
                            }
                            
                            // Anonymous Toggle
                            HStack {
                                Image(systemName: isAnonymous ? "eye.slash.fill" : "person.fill")
                                    .foregroundStyle(.blue)
                                
                                Text("Sponsor Anonymously")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                
                                Spacer()
                                
                                Toggle("", isOn: $isAnonymous)
                                    .labelsHidden()
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        }
                        
                        // Payment + Submit Buttons (only show if not already sponsored and not past date)
                        if existingSponsorship == nil && !isPastDate {
                            VStack(spacing: 12) {
                                Button(action: {
                                    openSquareCheckout()
                                    didOpenPaymentLink = true
                                }) {
                                    HStack {
                                        Image(systemName: "creditcard.fill")
                                        Text("Continue to Payment")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isFormValid ? .blue : .gray)
                                    .cornerRadius(15)
                                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                                }
                                .disabled(!isFormValid || isSubmitting)
                                
                                Button(action: submitSponsorship) {
                                    HStack {
                                        if isSubmitting {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("I've Paid - Confirm Sponsorship")
                                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        }
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background((isFormValid && didOpenPaymentLink) ? .green : .gray)
                                    .cornerRadius(15)
                                    .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                                }
                                .disabled(!isFormValid || !didOpenPaymentLink || isSubmitting)
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                        }
                        
                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.red)
                                .padding()
                                .background(.red.opacity(0.1))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Sponsorship Confirmed!", isPresented: $showingConfirmation) {
                Button("Pay Now") {
                    openSquareCheckout()
                }
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Thank you for sponsoring Kiddush! If needed, you can tap Pay Now again.")
            }
            .alert("Delete Sponsorship?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteExistingSponsorship()
                }
            } message: {
                Text("This will remove this sponsorship. Only admins should do this.")
            }
            .onAppear {
                if let storedRaw = UserDefaults.standard.string(forKey: tierStorageKey),
                   let storedTier = SponsorshipTier(rawValue: storedRaw) {
                    selectedTier = storedTier
                }
                loadHebrewDate()
                checkExistingSponsorship()
            }
        }
    }
    
    func loadHebrewDate() {
        Task {
            let service = HebrewCalendarService()
            hebrewDate = await service.fetchHebrewDate(for: shabbatDate)
            print("🔍 SponsorshipForm - Hebrew date loaded: '\(hebrewDate ?? "none")'")
            print("🔍 SponsorshipForm - Parsha: '\(shabbatTime?.parsha ?? "none")'")
        }
    }
    
    func checkExistingSponsorship() {
        existingSponsorship = firestoreManager.getSponsorship(for: shabbatDate)
        if let existing = existingSponsorship {
            if let matchedTier = SponsorshipTier.allCases.first(where: { $0.amount == existing.tierAmount }) {
                selectedTier = matchedTier
            }
            print("⚠️ Date already sponsored by: \(existing.sponsorEmail)")
            print("💰 Existing sponsorship amount: \(existing.tierAmount)")
        } else {
            print("✅ Date is available for sponsorship")
        }
    }
    
    var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && email.contains("@") && !occasion.isEmpty
    }
    
    func submitSponsorship() {
        guard isFormValid, didOpenPaymentLink else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            print("💰 Submitting sponsorship tier: \(selectedTier.title) ($\(selectedTier.amount))")
            let sponsorship = KiddushSponsorship(
                date: shabbatDate,
                sponsorName: name,
                sponsorEmail: email,
                occasion: occasion,
                tierName: selectedTier.title,
                tierAmount: selectedTier.amount,
                isAnonymous: isAnonymous
            )
            
            let success = await firestoreManager.sponsorKiddush(sponsorship)
            
            if success {
                // Give Firestore listener a moment to update
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                await MainActor.run {
                    UserDefaults.standard.removeObject(forKey: tierStorageKey)
                    isSubmitting = false
                    showingConfirmation = true
                }
                // TODO: Send confirmation email via backend
            } else {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "This Shabbat has already been sponsored. Please choose another date."
                }
            }
        }
    }

    func deleteExistingSponsorship() {
        guard canAdminDeleteSponsorship else { return }
        isDeletingSponsorship = true
        errorMessage = nil

        Task {
            let success = await firestoreManager.deleteSponsorshipByDate(shabbatDate)
            await MainActor.run {
                isDeletingSponsorship = false
                if success {
                    existingSponsorship = nil
                } else {
                    errorMessage = firestoreManager.errorMessage ?? "Could not delete sponsorship."
                }
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func openSquareCheckout() {
        guard let url = URL(string: squareCheckoutURL) else { return }
        openURL(url)
    }
}

private struct SponsorshipTierOptionCard: View {
    let tier: SponsorshipTier
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSelected ? tier.accentColor.opacity(0.16) : Color(red: 0.94, green: 0.95, blue: 0.98))
                    .frame(width: 30, height: 30)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? tier.accentColor : Color.secondary.opacity(0.7))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(tier.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.88))
            }
            
            Spacer()
            
            Text("$\(tier.amount)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : tier.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? tier.accentColor : tier.accentColor.opacity(0.13))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? tier.accentColor.opacity(0.08) : Color.white.opacity(0.56))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? tier.accentColor.opacity(0.55) : Color(red: 0.9, green: 0.91, blue: 0.94), lineWidth: isSelected ? 1.6 : 1)
        )
        .shadow(color: isSelected ? tier.accentColor.opacity(0.2) : .clear, radius: 8, x: 0, y: 3)
        .scaleEffect(isSelected ? 1.01 : 1.0)
    }
}

private struct SponsorshipTimeCard: View {
    let icon: String
    let title: String
    let timeText: String
    let accent: Color
    let iconBackground: Color
    
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
                .padding(8)
                .background(
                    Circle()
                        .fill(iconBackground)
                )
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(timeText)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.67))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    SponsorshipFormView(
        shabbatDate: Date(),
        shabbatTime: ShabbatTime(
            date: Date(),
            candleLighting: Date(),
            havdalah: Date().addingTimeInterval(25 * 3600),
            parsha: "Vayeira"
        ),
        currentUser: User(name: "John Doe", email: "john@example.com", totalPledged: 0),
        firestoreManager: FirestoreManager()
    )
}
