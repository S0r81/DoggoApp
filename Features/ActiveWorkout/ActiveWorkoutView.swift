import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ActiveWorkoutViewModel()
    
    // We need to fetch exercises to handle the "Start Dummy Workout" logic if needed
    @Query private var exercises: [Exercise]
    
    @State private var showExerciseList = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Header: Timer and Session Info
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Session")
                            .font(.headline)
                        Text(formatTime(viewModel.elapsedSeconds))
                            .font(.largeTitle)
                            .monospacedDigit()
                    }
                    Spacer()
                    
                    Button("Finish") {
                        viewModel.finishWorkout()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding()
                
                Divider()
                
                // The List of Sets
                if let session = viewModel.currentSession {
                    List {
                        // 1. Get unique exercises from this session
                        // We filter the sets to find which exercises are being used
                        let activeExercises = getExercises(from: session)
                        
                        ForEach(activeExercises) { exercise in
                            // 2. Create a dynamic section for each exercise
                            Section(header: Text(exercise.name).font(.title3).bold()) {
                                
                                // 3. Filter sets belonging ONLY to this exercise
                                let relevantSets = session.sets
                                    .filter { $0.exercise == exercise }
                                    .sorted { $0.orderIndex < $1.orderIndex }
                                
                                // Inside ActiveWorkoutView.swift (inside the List)

                                ForEach(relevantSets) { set in
                                    let index = (relevantSets.firstIndex(of: set) ?? 0) + 1
                                    
                                    // THE SWITCH LOGIC
                                    if exercise.type == "Cardio" {
                                        CardioSetRowView(set: set, index: index)
                                    } else {
                                        SetRowView(set: set, index: index)
                                    }
                                }
                                .onDelete { indexSet in   // <--- ADD THIS BLOCK
                                    for index in indexSet {
                                        let setToDelete = relevantSets[index]
                                        viewModel.deleteSet(setToDelete)
                                    }
                                }
                                
                                // "Add Set" button specifically for this exercise
                                Button("Add Set") {
                                    viewModel.addSet(to: exercise, weight: 0, reps: 0)
                                }
                            }
                        }
                        
                        // "Add New Exercise" Button
                        Button(action: {
                            showExerciseList = true
                        }) {
                            Label("Add Exercise", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .sheet(isPresented: $showExerciseList) {
                        if let session = viewModel.currentSession {
                            ExerciseListView(currentSession: session) { selectedExercise in
                                viewModel.addSet(to: selectedExercise, weight: 0, reps: 0)
                            }
                        }
                    }
                } else {
                    // Start Button (If no workout is active)
                    ContentUnavailableView("No Active Workout", systemImage: "dumbbell.fill")
                    
                    Button("Start Workout") {
                        startDummyWorkout()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("Log Workout")
            .onAppear {
                // When this tab opens, check if there is a session running
                if viewModel.currentSession == nil {
                    viewModel.checkForActiveSession(context: modelContext)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    // Helper to extract unique exercises from the session
    private func getExercises(from session: WorkoutSession) -> [Exercise] {
        let allExercises = session.sets.compactMap { $0.exercise }
        // Remove duplicates while keeping order
        var unique: [Exercise] = []
        for exercise in allExercises {
            if !unique.contains(where: { $0.id == exercise.id }) {
                unique.append(exercise)
            }
        }
        return unique
    }
    
    private func startDummyWorkout() {
        viewModel.startNewWorkout(context: modelContext)
        // Note: We don't automatically add a set anymore,
        // we let the user click "Add Exercise"
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
