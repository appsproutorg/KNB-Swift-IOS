//
//  NetworkStatusBanner.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct NetworkStatusBanner: View {
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
            Text("No Internet Connection")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.red)
        .padding(.top, 0)
    }
}

#Preview {
    VStack {
        NetworkStatusBanner(isConnected: false)
        Spacer()
    }
}

