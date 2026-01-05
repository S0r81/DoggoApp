//
//  Untitled.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//
import SwiftUI
import SwiftData

struct RoutineCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var routineToEdit: Routine?
    
    @State private var name = ""
    @State private var routineItems: [RoutineItem] = [] // We work with Item objects now, not just Exercises
    
    @State private var showExercisePicker = false
    @State private var itemToConfigure: RoutineItem? // Tracks which exercise we are editing sets for
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Routine Details")) {
                    TextField("Routine Name", text: $name)
                }
                
                Section(header: Text("Exercises")) {
                    if routineItems.isEmpty {
                        Text("No exercises added")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(routineItems) { item in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.gray)
                                
                                VStack(alignment: .leading) {
                                    Text(item.exercise?.name ?? "Unknown")
                                        .font(.headline)
                                    Text("\(item.templateSets.count) sets")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                // Configure Button (Gear Icon)
                                Button(action: {
                                    itemToConfigure = item
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundStyle(.blue)
                                        .padding(8)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onMove(perform: moveItem)
                        .onDelete(perform: deleteItem)
                    }
                    
                    Button(action: { showExercisePicker = true }) {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(routineToEdit == nil ? "New Routine" : "Edit Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRoutine() }
                        .disabled(name.isEmpty || routineItems.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .onAppear {
                if let routine = routineToEdit {
                    name = routine.name
                    // Load existing items
                    routineItems = routine.items.sorted { $0.orderIndex < $1.orderIndex }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExerciseSelectionSheet(onSelect: addExercise)
            }
            // THE CONFIGURATION SHEET
            .sheet(item: $itemToConfigure) { item in
                SetConfigurationView(item: item)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Logic
    
    private func addExercise(_ exercise: Exercise) {
        // Create a new item wrapper
        let newItem = RoutineItem(orderIndex: routineItems.count, exercise: exercise)
        
        // Default: Add 3 sets of 10 reps automatically so it's not empty
        for i in 0..<3 {
            let set = RoutineSetTemplate(orderIndex: i, targetReps: 10)
            newItem.templateSets.append(set)
        }
        
        routineItems.append(newItem)
    }
    
    private func moveItem(from source: IndexSet, to destination: Int) {
        routineItems.move(fromOffsets: source, toOffset: destination)
        // Update indices
        for (index, item) in routineItems.enumerated() {
            item.orderIndex = index
        }
    }
    
    private func deleteItem(at offsets: IndexSet) {
        routineItems.remove(atOffsets: offsets)
    }
    
    private func saveRoutine() {
        let routine = routineToEdit ?? Routine(name: name)
        routine.name = name
        
        if routineToEdit == nil {
            modelContext.insert(routine)
        }
        
        // Clear old relations if editing (simplest way to ensure order)
        routine.items = []
        
        // Save new items
        for (index, item) in routineItems.enumerated() {
            item.orderIndex = index
            item.routine = routine // Link parent
            routine.items.append(item) // Link child
            
            // Note: Since 'item' is a class created in this View state,
            // we need to make sure it's inserted into the context
            modelContext.insert(item)
        }
        
        dismiss()
    }
}

// MARK: - Subview: Set Configuration Sheet
// MARK: - Subview: Set Configuration Sheet
struct SetConfigurationView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var item: RoutineItem
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Sets & Reps")) {
                    if item.templateSets.isEmpty {
                        Text("No sets configured.")
                            .foregroundStyle(.secondary)
                    } else {
                        // We sort the sets to keep them in order (Set 1, Set 2...)
                        ForEach(item.templateSets.sorted(by: { $0.orderIndex < $1.orderIndex })) { set in
                            // Call the helper view here
                            SetRowConfig(set: set)
                        }
                        .onDelete { indexSet in
                            // We have to find the correct set object to delete since the list is sorted
                            let sortedSets = item.templateSets.sorted(by: { $0.orderIndex < $1.orderIndex })
                            for index in indexSet {
                                let setToRemove = sortedSets[index]
                                if let realIndex = item.templateSets.firstIndex(of: setToRemove) {
                                    item.templateSets.remove(at: realIndex)
                                }
                            }
                            reindexSets()
                        }
                    }
                    
                    Button("Add Set") {
                        withAnimation {
                            let nextIndex = item.templateSets.count
                            // Default to matching the previous set's reps, or 10
                            let reps = item.templateSets.last?.targetReps ?? 10
                            let newSet = RoutineSetTemplate(orderIndex: nextIndex, targetReps: reps)
                            item.templateSets.append(newSet)
                        }
                    }
                }
            }
            .navigationTitle(item.exercise?.name ?? "Configure")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
    
    private func reindexSets() {
        // Re-assign indexes (0, 1, 2...) after deletion so gaps don't appear
        let sortedSets = item.templateSets.sorted(by: { $0.orderIndex < $1.orderIndex })
        for (index, set) in sortedSets.enumerated() {
            set.orderIndex = index
        }
    }
}

// MARK: - Helper Row for Binding
struct SetRowConfig: View {
    @Bindable var set: RoutineSetTemplate
    
    var body: some View {
        HStack {
            Text("Set \(set.orderIndex + 1)")
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Spacer()
            
            // Now '$set' works because we are in a dedicated view with @Bindable
            Stepper("\(set.targetReps) Reps", value: $set.targetReps, in: 1...100)
                .fixedSize()
        }
    }
}

// Helper: Selection Sheet (Modified to return single exercise)
struct ExerciseSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Exercise.name) var allExercises: [Exercise]
    var onSelect: (Exercise) -> Void
    
    var body: some View {
        NavigationStack {
            List(allExercises) { exercise in
                Button(action: {
                    onSelect(exercise)
                    dismiss()
                }) {
                    Text(exercise.name)
                        .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Select Exercise")
        }
    }
}
