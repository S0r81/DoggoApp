//
//  ExerciseCreationView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

struct ExerciseCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var selectedMuscle: String = "Chest"
    @State private var selectedType: String = "Strength"
    
    // Expanded list for better categorization
    let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio", "Full Body"]
    let types = ["Strength", "Cardio", "Olympic", "Accessory"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Exercise Name (e.g., Squat)", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    Picker("Muscle Group", selection: $selectedMuscle) {
                        ForEach(muscleGroups, id: \.self) { muscle in
                            Text(muscle).tag(muscle)
                        }
                    }
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(types, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // NEW: Haptic Feedback
                        HapticManager.shared.notification(type: .success)
                        saveExercise()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveExercise() {
        // Matches the updated Model below
        let newExercise = Exercise(name: name, type: selectedType, muscleGroup: selectedMuscle)
        modelContext.insert(newExercise)
        dismiss()
    }
}
