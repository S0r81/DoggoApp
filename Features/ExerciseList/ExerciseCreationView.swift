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
    
    // Hardcoded list for now (you can expand this later)
    let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio"]
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
                        saveExercise()
                    }
                    .disabled(name.isEmpty) // Disable if no name typed
                }
            }
        }
    }
    
    private func saveExercise() {
        let newExercise = Exercise(name: name, muscleGroup: selectedMuscle, type: selectedType)
        modelContext.insert(newExercise)
        dismiss()
    }
}
