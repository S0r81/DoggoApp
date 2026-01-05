//
//  ExerciseListView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // The specific workout session we want to add exercises to
    var currentSession: WorkoutSession
    var onAddExercise: (Exercise) -> Void
    
    @Query(sort: \Exercise.name) var exercises: [Exercise]
    @State private var searchText = ""
    @State private var showCreationSheet = false
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        } else {
            return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises) { exercise in
                    Button(action: {
                        onAddExercise(exercise)
                        dismiss() // Close the list after selecting
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                    .font(.headline)
                                Text(exercise.muscleGroup)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreationSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreationSheet) {
                ExerciseCreationView()
                    .presentationDetents([.medium]) // Makes it a nice half-sheet
            }
        }
    }
}
