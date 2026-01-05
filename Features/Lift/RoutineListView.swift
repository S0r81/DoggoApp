import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: Int
    
    // Toggle between the two modes
    @State private var selectedView = "Routines"
    let views = ["Routines", "Exercises"]
    
    // Sheets
    @State private var showCreateRoutine = false
    @State private var showCreateExercise = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // 1. Segmented Control
                Picker("View", selection: $selectedView) {
                    ForEach(views, id: \.self) { viewName in
                        Text(viewName)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // 2. The Content
                if selectedView == "Routines" {
                    RoutineListContent(selectedTab: $selectedTab)
                } else {
                    ExerciseLibraryContent()
                }
            }
            .navigationTitle("Lift")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if selectedView == "Routines" {
                            showCreateRoutine = true
                        } else {
                            showCreateExercise = true
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            // Sheet for Routines
            .sheet(isPresented: $showCreateRoutine) {
                RoutineCreationView()
            }
            // Sheet for Exercises
            .sheet(isPresented: $showCreateExercise) {
                ExerciseCreationView()
                    .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Subview: Routine List
struct RoutineListContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query var routines: [Routine]
    @Binding var selectedTab: Int
    
    // State to track which routine we are editing
    @State private var routineToEdit: Routine?
    
    var body: some View {
        List {
            if routines.isEmpty {
                ContentUnavailableView("No Routines", systemImage: "clipboard")
            } else {
                ForEach(routines) { routine in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(routine.name)
                                .font(.headline)
                            Text("\(routine.items.count) exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // EDIT BUTTON
                        Button(action: {
                            routineToEdit = routine
                        }) {
                            Image(systemName: "pencil.circle")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain) // Prevents clicking the whole row
                        .padding(.trailing, 8)
                        
                        // START BUTTON
                        Button("Start") {
                            startRoutine(routine)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteRoutine)
            }
        }
        // This sheet triggers whenever 'routineToEdit' is not nil
        .sheet(item: $routineToEdit) { routine in
            RoutineCreationView(routineToEdit: routine)
        }
    }
    
    // ... startRoutine and deleteRoutine remain the same ...
    private func startRoutine(_ routine: Routine) {
        let tempVM = ActiveWorkoutViewModel()
        tempVM.startWorkout(from: routine, context: modelContext)
        selectedTab = 2
    }
    
    private func deleteRoutine(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routines[index])
        }
    }
}

// MARK: - Subview: Exercise List (Read-Only Manager)
struct ExerciseLibraryContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) var exercises: [Exercise]
    
    var body: some View {
        List {
            if exercises.isEmpty {
                ContentUnavailableView("No Exercises", systemImage: "dumbbell")
            } else {
                ForEach(exercises) { exercise in
                    // Make the row clickable!
                    NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                                .font(.headline)
                            HStack {
                                Text(exercise.muscleGroup)
                                Text("•")
                                Text(exercise.type)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteExercise)
            }
        }
    }
    
    private func deleteExercise(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(exercises[index])
        }
    }
}
