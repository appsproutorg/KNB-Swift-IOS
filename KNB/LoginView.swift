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
    
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo and title
                VStack(spacing: 15) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    Text("KNB")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Torah Honors Auction")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.bottom, 20)
                
                // Login form
                VStack(spacing: 20) {
                    if isSignUp {
                        CustomTextField(
                            icon: "person.fill",
                            placeholder: "Full Name",
                            text: $name
                        )
                    }
                    
                    CustomTextField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    
                    CustomTextField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password,
                        isSecure: true
                    )
                    
                    // Error message
                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Login/Sign Up button
                    Button(action: handleAuth) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isLoading)
                    .padding(.top, 10)
                    
                    // Toggle sign up
                    Button(action: { 
                        withAnimation(.spring(response: 0.3)) { 
                            isSignUp.toggle()
                            authManager.errorMessage = nil
                        } 
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 40)
                .background(.ultraThinMaterial)
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
    }
    
    private func handleAuth() {
        // Validate inputs
        guard !email.isEmpty, !password.isEmpty else {
            authManager.errorMessage = "Please fill in all fields"
            return
        }
        
        if isSignUp && name.isEmpty {
            authManager.errorMessage = "Please enter your name"
            return
        }
        
        if password.count < 6 {
            authManager.errorMessage = "Password must be at least 6 characters"
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

// MARK: - Custom TextField
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundStyle(.white)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.white.opacity(0.2))
        .cornerRadius(12)
    }
}
