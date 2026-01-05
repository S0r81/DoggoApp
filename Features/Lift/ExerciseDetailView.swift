//
//  ExerciseDetailView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exercise: Exercise
    
    // Sort sets by date
    var history: [WorkoutSet] {
        return exercise.sets.sorted { ($0.workoutSession?.date ?? Date()) < ($1.workoutSession?.date ?? Date()) }
    }
    
    var isCardio: Bool {
        exercise.type == "Cardio"
    }
    
    // MARK: - Stats Calculations
    
    var personalRecordValue: String {
        if isCardio {
            let maxDist = history.compactMap { $0.distance }.max() ?? 0
            return "\(maxDist.formatted()) mi"
        } else {
            let maxWeight = history.map { $0.weight }.max() ?? 0
            return "\(Int(maxWeight)) lbs"
        }
    }
    
    var personalRecordLabel: String {
        isCardio ? "Longest Run" : "Personal Record"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Header Stats
                HStack(spacing: 20) {
                    StatBox(
                        title: personalRecordLabel,
                        value: personalRecordValue,
                        color: .green
                    )
                    
                    StatBox(
                        title: "Total Sessions",
                        value: "\(history.count)",
                        color: .blue
                    )
                }
                .padding(.horizontal)
                
                // 2. The Chart
                if history.count > 1 {
                    VStack(alignment: .leading) {
                        Text(isCardio ? "Progress (Distance)" : "Progress (Max Weight)")
                            .font(.headline)
                        
                        Chart {
                            ForEach(history) { set in
                                if let date = set.workoutSession?.date {
                                    // CONDITIONAL PLOTTING
                                    if isCardio {
                                        // Plot Distance
                                        LineMark(
                                            x: .value("Date", date),
                                            y: .value("Distance", set.distance ?? 0)
                                        )
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(Color.accentColor)
                                        
                                        PointMark(
                                            x: .value("Date", date),
                                            y: .value("Distance", set.distance ?? 0)
                                        )
                                        .foregroundStyle(Color.accentColor)
                                    } else {
                                        // Plot Weight
                                        LineMark(
                                            x: .value("Date", date),
                                            y: .value("Weight", set.weight)
                                        )
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(Color.accentColor)
                                        
                                        PointMark(
                                            x: .value("Date", date),
                                            y: .value("Weight", set.weight)
                                        )
                                        .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                        .frame(height: 250)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                } else {
                    ContentUnavailableView("Not enough data for chart", systemImage: "chart.xyaxis.line")
                        .frame(height: 200)
                }
                
                // 3. History List
                VStack(alignment: .leading) {
                    Text("History")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(history.reversed()) { set in
                        HStack {
                            // Date
                            Text(set.workoutSession?.date.formattedDate ?? "Unknown")
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            Spacer()
                            
                            // THE ROW CONTENT
                            if isCardio {
                                // Cardio: 2.5 mi in 20 min
                                VStack(alignment: .trailing) {
                                    Text("\(set.distance?.formatted() ?? "0") mi")
                                        .bold()
                                    Text(formatDuration(minutes: set.duration ?? 0))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                // Strength: 225 lbs x 5
                                HStack {
                                    Text("\(Int(set.weight)) lbs")
                                        .bold()
                                    Text("x")
                                    Text("\(set.reps)")
                                }
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
        }
        .navigationTitle(exercise.name)
    }
    
    // Helper to format minutes nicely (e.g. 90 min -> 1h 30m)
    func formatDuration(minutes: Double) -> String {
        let totalSeconds = Int(minutes * 60)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m) min"
        }
    }
}

// Re-using the StatBox from before
struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}
