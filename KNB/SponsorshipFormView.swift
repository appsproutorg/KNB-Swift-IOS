//
//  SponsorshipFormView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct SponsorshipFormView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var firestoreManager: FirestoreManager
    
    let shabbatDate: Date
    let shabbatTime: ShabbatTime?
    let currentUser: User?
    
    @State private var name: String
    @State private var email: String
    @State private var occasion: String = ""
    @State private var isAnonymous: Bool = false
    @State private var isSubmitting = false
    @State private var showingConfirmation = false
    @State private var errorMessage: String?
    @State private var hebrewDate: String?
    @State private var existingSponsorship: KiddushSponsorship?
    
    var isPastDate: Bool {
        shabbatDate < Date()
    }
    
    init(shabbatDate: Date, shabbatTime: ShabbatTime?, currentUser: User?, firestoreManager: FirestoreManager) {
        self.shabbatDate = shabbatDate
        self.shabbatTime = shabbatTime
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
        if sponsorship.isAnonymous && !isSponsoredByCurrentUser {
            return "Anonymous Sponsor"
        }
        return sponsorship.sponsorName
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: shabbatDate)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Modern glassy background with mesh gradient effect
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.15),
                            Color.purple.opacity(0.12),
                            Color.pink.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Subtle overlay circles for depth
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.blue.opacity(0.15), .clear],
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
                                colors: [.purple.opacity(0.12), .clear],
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
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                                .padding(.top, 20)
                            
                            Text("Sponsor Kiddush")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            
                            // Gregorian Date
                            Text(formattedDate)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            // Hebrew Date (prominently displayed)
                            if let hebrewDate = hebrewDate {
                                Text(hebrewDate)
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Parsha (prominently displayed)
                            if let parsha = shabbatTime?.parsha {
                                HStack(spacing: 8) {
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 18))
                                    Text("Parashat \(parsha)")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // Candle Lighting & Havdalah Times
                            if let shabbatTime = shabbatTime {
                                HStack(spacing: 20) {
                                    // Candle Lighting
                                    VStack(spacing: 4) {
                                        Image(systemName: "light.max")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.orange)
                                        Text("Candle Lighting")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        Text(formatTime(shabbatTime.candleLighting))
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(.orange)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.orange.opacity(0.1))
                                    )
                                    
                                    // Havdalah
                                    VStack(spacing: 4) {
                                        Image(systemName: "moon.stars.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.purple)
                                        Text("Havdalah")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        Text(formatTime(shabbatTime.havdalah))
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(.purple)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.purple.opacity(0.1))
                                    )
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 10)
                        
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
                        
                        // Already Sponsored Banner with glassy design
                        if let sponsorship = existingSponsorship {
                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.green)
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Already Sponsored")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(.green)
                                        
                                        Text("Sponsored by: \(sponsorDisplayText)")
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        
                                        if isSponsoredByCurrentUser {
                                            Text("(This is your sponsorship)")
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundStyle(.blue)
                                        }
                                        
                                        Text("Occasion: \(sponsorship.occasion)")
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(16)
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
                        
                        // Price Card with modern glassy design
                        VStack(spacing: 8) {
                            Text("Sponsorship Amount")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Text("$500")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Payment details will be sent via email")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(.green.opacity(0.05))
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.green.opacity(0.3), .green.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            }
                        )
                        .shadow(color: .green.opacity(0.1), radius: 15, x: 0, y: 8)
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
                        
                        // Submit Button (only show if not already sponsored and not past date)
                        if existingSponsorship == nil && !isPastDate {
                        Button(action: submitSponsorship) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Confirm Sponsorship")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? .blue : .gray)
                            .cornerRadius(15)
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(!isFormValid || isSubmitting)
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
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Thank you for sponsoring Kiddush! A confirmation email with payment details will be sent to \(email).")
            }
            .onAppear {
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
            print("⚠️ Date already sponsored by: \(existing.sponsorEmail)")
        } else {
            print("✅ Date is available for sponsorship")
        }
    }
    
    var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && email.contains("@") && !occasion.isEmpty
    }
    
    func submitSponsorship() {
        guard isFormValid else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            let sponsorship = KiddushSponsorship(
                date: shabbatDate,
                sponsorName: name,
                sponsorEmail: email,
                occasion: occasion,
                isAnonymous: isAnonymous
            )
            
            let success = await firestoreManager.sponsorKiddush(sponsorship)
            
            if success {
                // Give Firestore listener a moment to update
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                await MainActor.run {
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
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

