//
//  CardioSetRowView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI

struct CardioSetRowView: View {
    @Bindable var set: WorkoutSet
    var index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Interval Number
            Text("\(index)")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            // 2. Distance Input
            VStack(spacing: 2) {
                Text("Distance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                TextField("0", value: $set.distance, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        // CHANGE: Menu to toggle units (mi/km)
                        Menu {
                            Button("mi") { set.unit = "mi" }
                            Button("km") { set.unit = "km" }
                        } label: {
                            Text(set.unit)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.5)) // Subtle background for tap target
                                .cornerRadius(4)
                        }
                        .padding(.trailing, 8),
                        alignment: .trailing
                    )
            }
            .frame(maxWidth: .infinity)
            
            // 3. Duration Input (Time is always "min", so no change needed)
            VStack(spacing: 2) {
                Text("Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                TextField("0", value: $set.duration, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        Text("min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8),
                        alignment: .trailing
                    )
            }
            .frame(maxWidth: .infinity)
            
            // 4. Completion Checkbox
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                withAnimation(.snappy) {
                    set.isCompleted.toggle()
                }
            }) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(set.isCompleted ? .green : .gray.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
