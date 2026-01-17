import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ActiveWorkoutViewModel()
    
    // UI State
    @State private var showExerciseList = false
    @State private var collapsedExercises: Set<UUID> = []
    
    // We only need this query if we plan to use it for the picker
    @Query private var exercises: [Exercise]
    
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
                
                // 2. The Main List
                if let session = viewModel.currentSession {
                    List {
                        let activeExercises = getExercises(from: session)
                        
                        ForEach(activeExercises, id: \.self) { exercise in
                            Section {
                                // ONLY SHOW SETS IF NOT COLLAPSED
                                if !collapsedExercises.contains(exercise.id) {
                                    let relevantSets = getSets(for: exercise, in: session)
                                    
                                    ForEach(relevantSets) { set in
                                        let index = (relevantSets.firstIndex(of: set) ?? 0) + 1
                                        
                                        // Use the specific row based on type
                                        if exercise.type == "Cardio" {
                                            CardioSetRowView(set: set, index: index)
                                                .listRowSeparator(.hidden)
                                        } else {
                                            SetRowView(set: set, index: index) {
                                                // Trigger Rest Timer when checked
                                                viewModel.startRestTimer()
                                            }
                                            .listRowSeparator(.hidden)
                                        }
                                    }
                                    .onDelete { indexSet in
                                        deleteSets(at: indexSet, from: relevantSets)
                                    }
                                    
                                    // ADD SET BUTTON
                                    Button {
                                        HapticManager.shared.impact(style: .light)
                                        viewModel.addSet(to: exercise, weight: 0, reps: 0)
                                    } label: {
                                        Label("Add Set", systemImage: "plus.circle.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(.blue)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.vertical, 4)
                                    }
                                }
                            } header: {
                                // STICKY HEADER WITH REORDERING
                                WorkoutSectionHeader(
                                    exercise: exercise,
                                    session: session,
                                    isCollapsed: collapsedExercises.contains(exercise.id),
                                    onToggleCollapse: { toggleCollapse(for: exercise) },
                                    onMoveUp: { moveExercise(exercise, direction: -1) },
                                    onMoveDown: { moveExercise(exercise, direction: 1) }
                                )
                            }
                        }
                        
                        // ADD EXERCISE BUTTON AT BOTTOM
                        Section {
                            Button {
                                showExerciseList = true
                            } label: {
                                Label("Add Exercise", systemImage: "plus")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    // SMOOTH ANIMATION
                    .animation(.default, value: collapsedExercises)
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
            .navigationBarTitleDisplayMode(.inline)
            
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
    
    // MARK: - Helpers
    
    private func getExercises(from session: WorkoutSession) -> [Exercise] {
        // We trust the sets orderIndex to keep exercises sorted
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
    
    private func getSets(for exercise: Exercise, in session: WorkoutSession) -> [WorkoutSet] {
        session.sets
            .filter { $0.exercise == exercise }
            .sorted { $0.orderIndex < $1.orderIndex }
    }
    
    private func toggleCollapse(for exercise: Exercise) {
        withAnimation {
            if collapsedExercises.contains(exercise.id) {
                collapsedExercises.remove(exercise.id)
            } else {
                collapsedExercises.insert(exercise.id)
            }
        }
    }
    
    private func deleteSets(at offsets: IndexSet, from sets: [WorkoutSet]) {
        for index in offsets {
            let setToDelete = sets[index]
            viewModel.deleteSet(setToDelete)
        }
    }
    
    // MARK: - REORDER LOGIC
    private func moveExercise(_ exercise: Exercise, direction: Int) {
        guard let session = viewModel.currentSession else { return }
        
        // 1. Get Current Order
        var currentOrder = getExercises(from: session)
        
        // 2. Find indices
        guard let currentIndex = currentOrder.firstIndex(of: exercise) else { return }
        let newIndex = currentIndex + direction
        
        // 3. Safety Check
        guard newIndex >= 0 && newIndex < currentOrder.count else { return }
        
        // 4. Perform the swap
        withAnimation {
            currentOrder.swapAt(currentIndex, newIndex)
            
            // 5. Update Database Order
            // We re-assign 'orderIndex' for ALL sets based on the new exercise order
            var globalSetIndex = 0
            
            for ex in currentOrder {
                // Get sets for this exercise, maintain their internal order
                let setsForExercise = getSets(for: ex, in: session)
                
                for set in setsForExercise {
                    set.orderIndex = globalSetIndex
                    globalSetIndex += 1
                }
            }
        }
    }
}

// MARK: - Subviews

struct WorkoutHeaderView: View {
    let elapsedSeconds: Int
    let onFinish: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Current Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Text(formatTime(elapsedSeconds))
                    .font(.largeTitle)
                    .monospacedDigit()
                    .fontWeight(.bold)
            }
            Spacer()
            
            Button("Finish") {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green) // Green implies "Done/Save"
            .fontWeight(.bold)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct WorkoutSectionHeader: View {
    let exercise: Exercise
    let session: WorkoutSession
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    
    // Reorder callbacks
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    
    // Helper to find the AI Note
    private var aiNote: String? {
        session.sets
            .first(where: { $0.exercise == exercise && $0.routineItem?.note != nil })?
            .routineItem?.note
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.name)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
                    .textCase(nil)
                
                Spacer()
                
                // REORDER BUTTONS
                HStack(spacing: 0) {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                            .font(.caption.bold())
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                            .font(.caption.bold())
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
                
                // COLLAPSE BUTTON
                Button(action: onToggleCollapse) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.blue)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // AI NOTE
            if let note = aiNote, !note.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption2)
                    Text(note)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.purple)
                .textCase(nil)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }
}
