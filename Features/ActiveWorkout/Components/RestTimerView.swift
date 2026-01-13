//
//  RestTimerView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI

struct RestTimerView: View {
    let seconds: Int
    var onAdd: () -> Void
    var onSkip: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 1. The Time Display
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption)
                Text(formatSeconds(seconds))
                    .monospacedDigit()
                    .bold()
            }
            .foregroundStyle(.white)
            
            Spacer()
            
            // 2. Controls
            HStack(spacing: 12) {
                Button(action: onAdd) {
                    Text("+30s")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
                .foregroundStyle(.white)
                
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .padding(6)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .foregroundStyle(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.9)) // Dark background
        .cornerRadius(30)
        .shadow(radius: 10)
        .padding(.horizontal)
    }
    
    private func formatSeconds(_ total: Int) -> String {
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
