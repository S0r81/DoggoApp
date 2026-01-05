//
//  WorkoutDetailView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI

struct WorkoutDetailView: View {
    let session: WorkoutSession
    
    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: session.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: formatDuration(session.duration))
                LabeledContent("Total Sets", value: "\(session.sets.count)")
            }
            
            // Re-use the logic to group sets by exercise
            ForEach(getExercises(from: session)) { exercise in
                Section(header: Text(exercise.name).font(.headline)) {
                    let relevantSets = session.sets
                        .filter { $0.exercise == exercise }
                        .sorted { $0.orderIndex < $1.orderIndex }
                    
                    ForEach(relevantSets) { set in
                        HStack {
                            Text("Set \((relevantSets.firstIndex(of: set) ?? 0) + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 40)
                            
                            Spacer()
                            
                            Text("\(set.weight, format: .number) lbs")
                                .bold()
                            Text("x")
                            Text("\(set.reps) reps")
                        }
                    }
                }
            }
        }
        .navigationTitle(session.name)
    }
    
    // Helpers
    private func getExercises(from session: WorkoutSession) -> [Exercise] {
        let allExercises = session.sets.compactMap { $0.exercise }
        var unique: [Exercise] = []
        for exercise in allExercises {
            if !unique.contains(where: { $0.id == exercise.id }) {
                unique.append(exercise)
            }
        }
        return unique
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}
