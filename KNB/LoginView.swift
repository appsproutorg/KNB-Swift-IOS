//
//  LoginView.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var name = ""
    @State private var isLoading = false
    @State private var showError = false

    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var isSendingReset = false
    @State private var resetEmailSent = false
    
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            // Background image with gray tint overlay (same as splash screen)
            // Fixed: Moved outside GeometryReader so it doesn't shrink when keyboard appears
            ZStack {
                Image("SplashBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                // Gray tint overlay
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
            }
            
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 30) {
                        Spacer(minLength: geometry.size.height > 600 ? 20 : 40)
                        
                        // Modern logo section
                        VStack(spacing: 20) {
                            // Icon in modern style - translucent like splash screen
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(red: 0.3, green: 0.5, blue: 0.95).opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color(red: 0.25, green: 0.5, blue: 0.92).opacity(0.15), radius: 15, x: 0, y: 5)
                                
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 38, weight: .regular))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.25, green: 0.5, blue: 0.92),
                                                Color(red: 0.3, green: 0.55, blue: 0.96)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .opacity(0.9)
                            }
                            
                            // The KNB App bubble (like splash screen)
                            Text("The KNB App")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Color(red: 0.4, green: 0.45, blue: 0.6))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.7))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(red: 0.3, green: 0.5, blue: 0.95).opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        
                        // Modern form card
                        VStack(spacing: 18) {
                        if isSignUp {
                            ModernInput(
                                icon: "person.fill",
                                placeholder: "Full Name",
                                text: $name
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                            .id("nameField")
                        }
                        
                        ModernInput(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $email
                        )
                        .id("emailField")
                        
                        ModernInput(
                            icon: "lock.fill",
                            placeholder: isSignUp ? "Password (min. 8 characters)" : "Password",
                            text: $password,
                            isSecure: true
                        )
                        .id("passwordField")
                        
                        // Modern error display
                        if let errorMessage = authManager.errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.95, green: 0.35, blue: 0.35),
                                                Color(red: 0.92, green: 0.3, blue: 0.4)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.25), radius: 10, x: 0, y: 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Modern action button
                        Button(action: handleAuth) {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.system(size: 17, weight: .semibold))
                                    
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 20))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.25, green: 0.5, blue: 0.92),
                                        Color(red: 0.3, green: 0.55, blue: 0.96)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: Color(red: 0.25, green: 0.5, blue: 0.92).opacity(0.35), radius: 15, x: 0, y: 8)
                        }
                        .disabled(isLoading)
                        .padding(.top, 4)
                        
                        // Toggle link
                        Button(action: { 
                            // Clear error and toggle with smooth animation
                            authManager.errorMessage = nil
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { 
                                isSignUp.toggle()
                            } 
                        }) {
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .foregroundStyle(Color.primary.opacity(0.85))
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .foregroundStyle(Color(red: 0.15, green: 0.4, blue: 0.85))
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 15, weight: .medium))
                        }
                        .disabled(isLoading)
                        .padding(.top, 4)
                        
                        // Forgot Password link (only show on sign in)
                        if !isSignUp {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showForgotPassword = true
                                }
                            }) {
                                Text("Forgot Password?")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.15, green: 0.4, blue: 0.85))
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(30)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 25, x: 0, y: 12)
                        }
                    )
                    .frame(maxWidth: geometry.size.width > 800 ? 500 : .infinity)
                    
                    Spacer(minLength: geometry.size.height > 600 ? 20 : 40)
                    
                    // Powered by App Sprout LLC
                    Text("Powered by App Sprout LLC")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(.bottom, max(60, geometry.size.height > 600 ? 80 : 100))
                    }
                    .frame(maxWidth: geometry.size.width > 800 ? 500 : .infinity)
                    .padding(.horizontal, geometry.size.width > 800 ? max(0, (geometry.size.width - 500) / 2) : 40)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Forgot Password Overlay
            if showForgotPassword {
                ForgotPasswordOverlay(
                    email: $forgotPasswordEmail,
                    isSending: $isSendingReset,
                    emailSent: $resetEmailSent,
                    authManager: authManager,
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showForgotPassword = false
                            forgotPasswordEmail = ""
                            resetEmailSent = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    func handleAuth() {
        // Validate inputs
        guard !email.isEmpty, !password.isEmpty else {
            authManager.errorMessage = "Please fill in all fields"
            return
        }
        
        if !email.isValidEmail {
            authManager.errorMessage = "Please enter a valid email address"
            return
        }
        
        if isSignUp && name.isEmpty {
            authManager.errorMessage = "Please enter your name"
            return
        }
        
        // Only validate password length during sign up
        if isSignUp && password.count < 8 {
            authManager.errorMessage = "Password must be at least 8 characters long"
            return
        }
        
        isLoading = true
        
        Task {
            let success: Bool
            if isSignUp {
                success = await authManager.signUp(email: email, password: password, name: name)
            } else {
                success = await authManager.signIn(email: email, password: password)
            }
            
            isLoading = false
            
            if success {
                // Clear fields on success
                email = ""
                password = ""
                name = ""
            }
        }
    }
}

// MARK: - Modern Input Field
struct ModernInput: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                    isFocused ?
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.5, blue: 0.92).opacity(0.15),
                            Color(red: 0.3, green: 0.55, blue: 0.96).opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                        LinearGradient(
                            colors: [
                                Color(red: 0.9, green: 0.91, blue: 0.95),
                                Color(red: 0.92, green: 0.93, blue: 0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(
                        isFocused ?
                        Color(red: 0.25, green: 0.5, blue: 0.92) :
                        Color(red: 0.5, green: 0.55, blue: 0.7)
                    )
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .tint(Color(red: 0.25, green: 0.5, blue: 0.92))
                    .focused($isFocused)
                    .textContentType(.password)
                    .submitLabel(.next)
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .tint(Color(red: 0.25, green: 0.5, blue: 0.92))
                    .focused($isFocused)
                    .textContentType(placeholder.lowercased().contains("email") ? .emailAddress : .none)
                    .keyboardType(placeholder.lowercased().contains("email") ? .emailAddress : .default)
                    .autocapitalization(placeholder.lowercased().contains("name") ? .words : .none)
                    .submitLabel(.next)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isFocused ?
                    Color.white.opacity(0.6) :
                    Color.white.opacity(0.5)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isFocused ?
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.5, blue: 0.92),
                            Color(red: 0.3, green: 0.55, blue: 0.96)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.87, blue: 0.92).opacity(0.5),
                            Color(red: 0.88, green: 0.89, blue: 0.94).opacity(0.5)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isFocused)
        .contentShape(Rectangle())
        .onTapGesture {
            // Ensure keyboard appears when tapping anywhere on the field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFocused = true
            }
        }
    }
}

// MARK: - Forgot Password Overlay
struct ForgotPasswordOverlay: View {
    @Binding var email: String
    @Binding var isSending: Bool
    @Binding var emailSent: Bool
    @ObservedObject var authManager: AuthenticationManager
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Content card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Reset Password")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
                
                if emailSent {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        
                        Text("Email Sent!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        VStack(spacing: 8) {
                            Text("Please check your inbox and follow the instructions to reset your password.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                            
                            Text("Don't forget to check your spam folder if you don't see it.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                } else {
                    VStack(spacing: 20) {
                        Text("Enter your email address and we'll send you instructions to reset your password.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        ModernInput(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $email
                        )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(.horizontal, 24)
                        
                        // Error message
                        if let errorMessage = authManager.errorMessage {
                            HStack(spacing: 8) {
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                        }
                        
                        Button(action: handleResetPassword) {
                            HStack(spacing: 10) {
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send Reset Email")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.25, green: 0.5, blue: 0.92),
                                        Color(red: 0.3, green: 0.55, blue: 0.96)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color(red: 0.25, green: 0.5, blue: 0.92).opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isSending || email.isEmpty)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 32)
            .frame(maxWidth: 500)
        }
    }
    
    private func handleResetPassword() {
        guard !email.isEmpty else {
            authManager.errorMessage = "Please enter your email address"
            return
        }
        
        if !email.isValidEmail {
            authManager.errorMessage = "Please enter a valid email address"
            return
        }
        
        isSending = true
        authManager.errorMessage = nil
        
        Task {
            let success = await authManager.resetPassword(email: email)
            isSending = false
            
            if success {
                emailSent = true
                // User must manually dismiss by clicking X
            }
        }
    }
}
