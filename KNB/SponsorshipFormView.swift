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
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Invisible tap area to dismiss keyboard
                        Color.clear
                            .frame(height: 0)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                hideKeyboard()
                            }
                        
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
                        }
                        .padding(.bottom, 10)
                        
                        // Already Sponsored Banner
                        if let sponsorship = existingSponsorship {
                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 30))
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
                                .padding()
                                .background(.green.opacity(0.1))
                                .cornerRadius(15)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Price Card
                        VStack(spacing: 8) {
                            Text("Sponsorship Amount")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Text("$500")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                            
                            Text("Payment details will be sent via email")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // Form Fields (only show if not already sponsored by someone else)
                        if existingSponsorship == nil || isSponsoredByCurrentUser {
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
                        
                        // Submit Button (only show if not already sponsored)
                        if existingSponsorship == nil {
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
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func loadHebrewDate() {
        Task {
            let service = HebrewCalendarService()
            hebrewDate = await service.fetchHebrewDate(for: shabbatDate)
        }
    }
    
    func checkExistingSponsorship() {
        existingSponsorship = firestoreManager.getSponsorship(for: shabbatDate)
    }
    
    var isFormValid: Bool {
        !name.isEmpty && isValidEmail(email) && !occasion.isEmpty
    }
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func submitSponsorship() {
        guard isFormValid else { return }
        
        // Dismiss keyboard
        hideKeyboard()
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                let sponsorship = KiddushSponsorship(
                    date: shabbatDate,
                    sponsorName: name,
                    sponsorEmail: email,
                    occasion: occasion,
                    isAnonymous: isAnonymous
                )
                
                let success = await firestoreManager.sponsorKiddush(sponsorship)
                
                if success {
                    // Success haptic
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                    showingConfirmation = true
                } else {
                    // Error haptic
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.error)
                    errorMessage = "This Shabbat has already been sponsored. Please choose another date."
                }
            }
            
            isSubmitting = false
        }
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

