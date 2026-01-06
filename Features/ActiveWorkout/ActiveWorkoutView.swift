import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ActiveWorkoutViewModel()
    
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
                        HapticManager.shared.notification(type: .success)
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
                        let activeExercises = getExercises(from: session)
                        
                        ForEach(activeExercises) { exercise in
                            Section(header: Text(exercise.name).font(.title3).bold()) {
                                
                                let relevantSets = session.sets
                                    .filter { $0.exercise == exercise }
                                    .sorted { $0.orderIndex < $1.orderIndex }
                                
                                ForEach(relevantSets) { set in
                                    let index = (relevantSets.firstIndex(of: set) ?? 0) + 1
                                    
                                    if exercise.type == "Cardio" {
                                        CardioSetRowView(set: set, index: index)
                                    } else {
                                        SetRowView(set: set, index: index)
                                    }
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        let setToDelete = relevantSets[index]
                                        viewModel.deleteSet(setToDelete)
                                    }
                                }
                                
                                Button("Add Set") {
                                    HapticManager.shared.impact(style: .light)
                                    viewModel.addSet(to: exercise, weight: 0, reps: 0)
                                }
                            }
                        }
                        
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
                if viewModel.currentSession == nil {
                    viewModel.checkForActiveSession(context: modelContext)
                }
            }
            // MARK: - TOOLBAR UPDATES
            .toolbar {
                // 1. The History Link (Top Right)
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: HistoryView()) {
                        Text("History")
                            .bold()
                    }
                }
                
                // 2. The Keyboard Done Button
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
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
    
    private func startDummyWorkout() {
        viewModel.startNewWorkout(context: modelContext)
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
