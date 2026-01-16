import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ActiveWorkoutViewModel()
    
    // We only need this query if we plan to use it for the picker
    @Query private var exercises: [Exercise]
    @State private var showExerciseList = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Header (Timer + Finish Button)
                WorkoutHeaderView(
                    elapsedSeconds: viewModel.elapsedSeconds,
                    onFinish: {
                        HapticManager.shared.notification(type: .success)
                        viewModel.finishWorkout()
                    }
                )
                
                Divider()
                
                // 2. The Main List (Extracted to subview to fix compiler error)
                if let session = viewModel.currentSession {
                    WorkoutSessionListView(
                        session: session,
                        viewModel: viewModel,
                        showExerciseList: $showExerciseList
                    )
                } else {
                    // Empty State
                    ContentUnavailableView("No Active Workout", systemImage: "dumbbell.fill")
                    
                    Button("Start Workout") {
                        viewModel.startNewWorkout(context: modelContext)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("Log Workout")
            // 3. THE REST TIMER OVERLAY
            .overlay(alignment: .bottom) {
                if viewModel.isRestTimerActive {
                    RestTimerView(
                        seconds: viewModel.restSecondsRemaining,
                        onAdd: { viewModel.addRestTime(30) },
                        onSkip: { viewModel.cancelRestTimer() }
                    )
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    // .animation(.snappy, value: viewModel.isRestTimerActive) // Optional animation
                }
            }
            .onAppear {
                if viewModel.currentSession == nil {
                    viewModel.checkForActiveSession(context: modelContext)
                }
            }
            // MARK: - TOOLBAR
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: HistoryView()) {
                        Text("History").bold()
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            // MARK: - SHEET
            .sheet(isPresented: $showExerciseList) {
                if let session = viewModel.currentSession {
                    ExerciseListView(currentSession: session) { selectedExercise in
                        viewModel.addSet(to: selectedExercise, weight: 0, reps: 0)
                    }
                }
            }
        }
    }
}

// MARK: - Subviews (Refactored to fix compiler timeout)

struct WorkoutHeaderView: View {
    let elapsedSeconds: Int
    let onFinish: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Current Session")
                    .font(.headline)
                Text(formatTime(elapsedSeconds))
                    .font(.largeTitle)
                    .monospacedDigit()
            }
            Spacer()
            
            Button("Finish") {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .background(Color(uiColor: .systemBackground)) // Solid background for sticky feel
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct WorkoutSessionListView: View {
    let session: WorkoutSession
    var viewModel: ActiveWorkoutViewModel
    @Binding var showExerciseList: Bool
    
    var body: some View {
        List {
            let activeExercises = getExercises(from: session)
            
            // FIX: Added 'id: \.self' to prevent the generic Range<Int> error
            ForEach(activeExercises, id: \.self) { exercise in
                
                // 1. Find sets for this exercise
                let relevantSets = session.sets
                    .filter { $0.exercise == exercise }
                    .sorted { $0.orderIndex < $1.orderIndex }
                
                // 2. Check if there is an AI Note attached to the routine item
                let aiNote = relevantSets.first?.routineItem?.note
                
                Section(header:
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.primary)
                    
                        // 3. Display the Note if it exists
                        if let note = aiNote, !note.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                    .font(.caption2)
                                Text(note)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.blue)
                            .textCase(nil) // Prevents iOS from forcing UPPERCASE
                        }
                    }
                    .padding(.vertical, 4)
                ) {
                    // FIX: Added 'id: \.self' here too for safety
                    ForEach(relevantSets, id: \.self) { set in
                        let index = (relevantSets.firstIndex(of: set) ?? 0) + 1
                        
                        if exercise.type == "Cardio" {
                            CardioSetRowView(set: set, index: index)
                        } else {
                            SetRowView(set: set, index: index) {
                                viewModel.startRestTimer()
                            }
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
    }
    
    private func getExercises(from session: WorkoutSession) -> [Exercise] {
        let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
        
        var unique: [Exercise] = []
        for set in sortedSets {
            if let exercise = set.exercise {
                // Ensure we haven't already added this exercise
                if !unique.contains(where: { $0.id == exercise.id }) {
                    unique.append(exercise)
                }
            }
        }
        return unique
    }
}
