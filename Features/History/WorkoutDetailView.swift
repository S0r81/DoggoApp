import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let session: WorkoutSession
    
    // Toggle for Edit Mode
    @State private var isEditing = false
    
    // NEW: Control the Exercise Picker Sheet
    @State private var showExerciseList = false
    
    var body: some View {
        List {
            // 1. Session Summary
            Section {
                LabeledContent("Date", value: session.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: formatDuration(session.duration))
                
                // Add Rename Feature
                if isEditing {
                    TextField("Session Name", text: Bindable(session).name)
                        .foregroundStyle(.blue)
                } else {
                    LabeledContent("Name", value: session.name)
                }
            }
            
            // 2. Exercise Loop
            let activeExercises = getExercises(from: session)
            
            ForEach(activeExercises) { exercise in
                Section(header: Text(exercise.name).font(.headline)) {
                    
                    let relevantSets = session.sets
                        .filter { $0.exercise == exercise }
                        .sorted { $0.orderIndex < $1.orderIndex }
                    
                    ForEach(relevantSets) { set in
                        // Use a subview to handle the Bindings cleanly
                        HistorySetRow(set: set, isEditing: isEditing, exerciseType: exercise.type) {
                            deleteSet(set)
                        }
                    }
                    
                    // NEW: Add Set Button (Only in Edit Mode)
                    if isEditing {
                        Button(action: {
                            addSet(to: exercise)
                        }) {
                            Label("Add Set", systemImage: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            
            // 3. NEW: Add Exercise Button (Only in Edit Mode)
            if isEditing {
                Section {
                    Button(action: {
                        showExerciseList = true
                    }) {
                        Label("Add Exercise", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Editing..." : session.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation {
                        isEditing.toggle()
                    }
                }
                .bold(isEditing)
            }
        }
        // 4. NEW: The Sheet to pick the exercise
        .sheet(isPresented: $showExerciseList) {
            // Reuse your existing Exercise List
            ExerciseListView(currentSession: session) { selectedExercise in
                // Logic: When selected, add a blank set to the session immediately
                addSet(to: selectedExercise)
            }
        }
    }
    
    // MARK: - Helpers
    
    // NEW: Logic to add a set to history
    private func addSet(to exercise: Exercise) {
        // 1. Find the highest order index in the session so we add it at the end
        let highestIndex = session.sets.map { $0.orderIndex }.max() ?? 0
        
        // 2. Determine default unit based on user preference
        let savedUnitSystem = UserDefaults.standard.string(forKey: "unitSystem")
        let defaultUnit = (savedUnitSystem == "metric") ? "kg" : "lbs"
        
        // 3. Create the set
        let newSet = WorkoutSet(weight: 0, reps: 0, orderIndex: highestIndex + 1, unit: defaultUnit)
        newSet.exercise = exercise
        newSet.workoutSession = session
        
        // 4. Save
        modelContext.insert(newSet)
    }
    
    private func deleteSet(_ set: WorkoutSet) {
        withAnimation {
            modelContext.delete(set)
        }
    }
    
    private func getExercises(from session: WorkoutSession) -> [Exercise] {
        let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
        var unique: [Exercise] = []
        for set in sortedSets {
            if let exercise = set.exercise {
                if !unique.contains(where: { $0.id == exercise.id }) {
                    unique.append(exercise)
                }
            }
        }
        return unique
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}

// MARK: - Subview: The Magic Row
// This switches between Text and TextField based on 'isEditing'
struct HistorySetRow: View {
    @Bindable var set: WorkoutSet
    var isEditing: Bool
    var exerciseType: String
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            // Set Index Label
            if let index = set.workoutSession?.sets.filter({ $0.exercise == set.exercise }).sorted(by: { $0.orderIndex < $1.orderIndex }).firstIndex(of: set) {
                Text("Set \(index + 1)")
                    .foregroundStyle(.secondary)
                    .frame(width: 45, alignment: .leading)
            } else {
                Text("-")
                    .frame(width: 45)
            }
            
            if isEditing {
                // --- EDIT MODE ---
                if exerciseType == "Cardio" {
                    // Cardio Inputs
                    TextField("Dist", value: $set.distance, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 70)
                    
                    // CHANGE: Toggle Unit Button (mi <-> km)
                    Button(set.unit) {
                        set.unit = (set.unit == "mi") ? "km" : "mi"
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    
                    TextField("Time", value: $set.duration, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 60)
                    Text("m")
                        .font(.caption)
                    
                } else {
                    // Strength Inputs
                    TextField("Lbs", value: $set.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                    
                    // CHANGE: Toggle Unit Button (lbs <-> kg)
                    Button(set.unit) {
                        set.unit = (set.unit == "lbs") ? "kg" : "lbs"
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    TextField("Reps", value: $set.reps, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 60)
                    
                    Text("r")
                        .font(.caption)
                }
                
                Spacer()
                
                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                
            } else {
                // --- READ-ONLY MODE ---
                Spacer()
                
                if exerciseType == "Cardio" {
                    VStack(alignment: .trailing) {
                        // CHANGE: Show stored unit
                        Text("\(set.distance?.formatted() ?? "0") \(set.unit)")
                            .bold()
                        Text("\(set.duration?.formatted() ?? "0") min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        // CHANGE: Show stored unit
                        Text("\(Int(set.weight)) \(set.unit)")
                            .bold()
                        Text("x")
                        Text("\(set.reps)")
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
