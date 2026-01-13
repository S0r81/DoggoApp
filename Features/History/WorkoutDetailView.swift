import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let session: WorkoutSession
    
    @State private var isEditing = false
    @State private var showExerciseList = false
    
    var body: some View {
        List {
            // 1. Session Summary
            Section {
                if isEditing {
                    DatePicker("Date", selection: Bindable(session).date, displayedComponents: [.date, .hourAndMinute])
                        .foregroundStyle(.blue)
                    
                    TextField("Session Name", text: Bindable(session).name)
                        .foregroundStyle(.blue)
                } else {
                    LabeledContent("Date", value: session.date.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Duration", value: formatDuration(session.duration))
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
                        HistorySetRow(set: set, isEditing: isEditing, exerciseType: exercise.type) {
                            deleteSet(set)
                        }
                    }
                    
                    if isEditing {
                        Button(action: {
                            addSet(to: exercise)
                        }) {
                            Label("Add Set", systemImage: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless) // FIX 1: Make button click instant
                    }
                }
            }
            
            // 3. Add Exercise Button
            if isEditing {
                Section {
                    Button(action: {
                        showExerciseList = true
                    }) {
                        Label("Add Exercise", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderless) // FIX 1: Make button click instant
                }
            }
        }
        .navigationTitle(isEditing ? "Editing..." : session.name)
        // FIX 2: Removed .onTapGesture (it was stealing clicks).
        // We keep this one, which works perfectly when you scroll.
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation {
                        isEditing.toggle()
                    }
                }
                .bold(isEditing)
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                     UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .sheet(isPresented: $showExerciseList) {
            ExerciseListView(currentSession: session) { selectedExercise in
                addSet(to: selectedExercise)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func addSet(to exercise: Exercise) {
        let highestIndex = session.sets.map { $0.orderIndex }.max() ?? 0
        let savedUnitSystem = UserDefaults.standard.string(forKey: "unitSystem")
        let defaultUnit = (savedUnitSystem == "metric") ? "kg" : "lbs"
        
        let newSet = WorkoutSet(weight: 0, reps: 0, orderIndex: highestIndex + 1, unit: defaultUnit)
        newSet.exercise = exercise
        newSet.workoutSession = session
        
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

// Subview remains unchanged...
struct HistorySetRow: View {
    @Bindable var set: WorkoutSet
    var isEditing: Bool
    var exerciseType: String
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            if let index = set.workoutSession?.sets.filter({ $0.exercise == set.exercise }).sorted(by: { $0.orderIndex < $1.orderIndex }).firstIndex(of: set) {
                Text("Set \(index + 1)")
                    .foregroundStyle(.secondary)
                    .frame(width: 45, alignment: .leading)
            } else {
                Text("-").frame(width: 45)
            }
            
            if isEditing {
                if exerciseType == "Cardio" {
                    TextField("Dist", value: $set.distance, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 70)
                    
                    Button(set.unit) {
                        set.unit = (set.unit == "mi") ? "km" : "mi"
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    
                    TextField("Time", value: $set.duration, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 60)
                    Text("m").font(.caption)
                    
                } else {
                    TextField("Lbs", value: $set.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                    
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
                    
                    Text("r").font(.caption)
                }
                
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash.fill").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                
            } else {
                Spacer()
                if exerciseType == "Cardio" {
                    VStack(alignment: .trailing) {
                        Text("\(set.distance?.formatted() ?? "0") \(set.unit)").bold()
                        Text("\(set.duration?.formatted() ?? "0") min").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text("\(Int(set.weight)) \(set.unit)").bold()
                        Text("x")
                        Text("\(set.reps)")
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
