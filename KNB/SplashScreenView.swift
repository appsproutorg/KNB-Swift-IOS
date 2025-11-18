//
//  SplashScreenView.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import SwiftUI

struct SplashScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var glowIntensity: Double = 0
    @State private var iconScale: CGFloat = 1.0
    @State private var isDataLoaded = false
    
    var onComplete: () -> Void
    var preloadData: (() async -> Void)?
    
    // Color scheme adaptive colors
    private var backgroundGradient: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.08, blue: 0.15),
                Color(red: 0.08, green: 0.10, blue: 0.18),
                Color(red: 0.10, green: 0.12, blue: 0.20)
            ]
        } else {
            return [
                Color(red: 0.88, green: 0.93, blue: 0.98),
                Color(red: 0.90, green: 0.94, blue: 0.99),
                Color(red: 0.92, green: 0.95, blue: 0.99)
            ]
        }
    }
    
    private var glowColor: Color {
        colorScheme == .dark ? Color(red: 0.4, green: 0.6, blue: 1.0) : Color(red: 0.3, green: 0.5, blue: 0.95)
    }
    
    private var circleBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.15, blue: 0.25) : Color.white
    }
    
    private var iconGradient: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.4, green: 0.65, blue: 1.0),
                Color(red: 0.5, green: 0.75, blue: 1.0)
            ]
        } else {
            return [
                Color(red: 0.25, green: 0.5, blue: 0.92),
                Color(red: 0.3, green: 0.55, blue: 0.96)
            ]
        }
    }
    
    private var subtitleColor: Color {
        colorScheme == .dark ? Color(red: 0.6, green: 0.65, blue: 0.75) : Color(red: 0.4, green: 0.45, blue: 0.6)
    }
    
    private var subtitleBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.15, green: 0.18, blue: 0.28).opacity(0.7) : Color.white.opacity(0.7)
    }
    
    var body: some View {
        ZStack {
            // Adaptive gradient background
            LinearGradient(
                colors: backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 35) {
                ZStack {
                    // Soft colorful glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    glowColor.opacity(glowIntensity * (colorScheme == .dark ? 0.3 : 0.2)),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 25)
                    
                    // Elegant icon container
                    ZStack {
                        // Soft outer ring
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        glowColor.opacity(colorScheme == .dark ? 0.2 : 0.15),
                                        glowColor.opacity(colorScheme == .dark ? 0.1 : 0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 130, height: 130)
                            .blur(radius: 6)
                        
                        // Main icon circle with subtle material
                        Circle()
                            .fill(circleBackgroundColor)
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                glowColor.opacity(colorScheme == .dark ? 0.4 : 0.25),
                                                glowColor.opacity(colorScheme == .dark ? 0.2 : 0.12)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: glowColor.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 20, x: 0, y: 8)
                        
                        // Book icon matching login theme
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: iconGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(iconScale)
                            .shadow(color: glowColor.opacity(colorScheme == .dark ? 0.4 : 0.25), radius: 8, x: 0, y: 2)
                    }
                    .scaleEffect(scale)
                }
                .opacity(opacity)
                
                // Clear, readable text
                VStack(spacing: 14) {
                    Text("KNB")
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: iconGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("The KNB App")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(subtitleColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(subtitleBackgroundColor)
                                .overlay(
                                    Capsule()
                                        .stroke(glowColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .opacity(opacity)
                .scaleEffect(scale)
            }
        }
        .onAppear {
            // Smooth entrance animation
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Gentle icon breathing animation
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                iconScale = 1.05
            }
            
            // Soft pulsing glow
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                glowIntensity = 1.0
            }
            
            // Preload data if provided
            if let preloadData = preloadData {
                Task {
                    await preloadData()
                    isDataLoaded = true
                    
                    // Wait minimum display time
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    
                    // Exit animation
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            opacity = 0
                            scale = 0.9
                        }
                    }
                    
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        onComplete()
                    }
                }
            } else {
                // No data to preload, use shorter duration
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        opacity = 0
                        scale = 0.9
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                }
            }
        }
    }
}
