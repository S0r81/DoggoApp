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
            
            // 2. Distance Input (Miles)
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
                        Text("mi").font(.caption2).foregroundStyle(.secondary).padding(.trailing, 4),
                        alignment: .trailing
                    )
            }
            .frame(maxWidth: .infinity)
            
            // 3. Duration Input (Minutes)
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
                        Text("min").font(.caption2).foregroundStyle(.secondary).padding(.trailing, 4),
                        alignment: .trailing
                    )
            }
            .frame(maxWidth: .infinity)
            
            // 4. Completion Checkbox
            Button(action: {
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
