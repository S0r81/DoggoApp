import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ActiveWorkoutViewModel()
    
    // UI State
    @State private var showExerciseList = false
    @State private var collapsedExercises: Set<UUID> = []
    
    // Helper Enum for Grouping
    enum DisplayUnit: Identifiable {
        case single(Exercise)
        case superset([Exercise])
        
        var id: String {
            switch self {
            case .single(let e): return e.id.uuidString
            case .superset(let es): return es.map { $0.id.uuidString }.joined()
            }
        }
    }
    
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
                        // Calculate Groups (Single vs Superset)
                        let groups = getDisplayGroups(from: session)
                        
                        ForEach(groups) { group in
                            switch group {
                            case .single(let exercise):
                                // Render Standard Exercise
                                renderExerciseSection(exercise, session: session)
                                
                            case .superset(let exercises):
                                // Render Superset Container
                                Section {
                                    ForEach(exercises) { exercise in
                                        renderExerciseSection(exercise, session: session, isSuperset: true)
                                    }
                                } header: {
                                    HStack {
                                        Image(systemName: "flame.fill").foregroundStyle(.pink)
                                        Text("SUPERSET").font(.headline).foregroundStyle(.pink)
                                    }
                                    .padding(.top, 8)
                                }
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
    
    // MARK: - Render Helpers
    
    @ViewBuilder
    private func renderExerciseSection(_ exercise: Exercise, session: WorkoutSession, isSuperset: Bool = false) -> some View {
        Section {
            // ONLY SHOW SETS IF NOT COLLAPSED
            if !collapsedExercises.contains(exercise.id) {
                let relevantSets = getSets(for: exercise, in: session)
                
                ForEach(relevantSets) { set in
                    let index = (relevantSets.firstIndex(of: set) ?? 0) + 1
                    
                    HStack(spacing: 0) {
                        // VISUAL: Pink Line for Superset Items
                        if isSuperset {
                            Rectangle()
                                .fill(Color.pink)
                                .frame(width: 4)
                                .padding(.trailing, 12)
                        }
                        
                        // Use the specific row based on type
                        if exercise.type == "Cardio" {
                            CardioSetRowView(set: set, index: index)
                        } else {
                            SetRowView(set: set, index: index) {
                                viewModel.startRestTimer()
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    let relevantSets = getSets(for: exercise, in: session)
                    for index in indexSet {
                        viewModel.deleteSet(relevantSets[index])
                    }
                }
                
                // ADD SET BUTTON
                Button {
                    HapticManager.shared.impact(style: .light)
                    viewModel.addSet(to: exercise, weight: 0, reps: 0)
                } label: {
                    HStack {
                        if isSuperset {
                            Color.clear.frame(width: 16) // Indent to match sets
                        }
                        Label("Add Set", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                }
            }
        } header: {
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
    
    // MARK: - Logic Helpers
    
    private func getDisplayGroups(from session: WorkoutSession) -> [DisplayUnit] {
        let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
        
        // Extract unique exercises in order
        var uniqueExercises: [Exercise] = []
        for set in sortedSets {
            if let ex = set.exercise, !uniqueExercises.contains(ex) {
                uniqueExercises.append(ex)
            }
        }
        
        var groups: [DisplayUnit] = []
        var i = 0
        
        while i < uniqueExercises.count {
            let currentEx = uniqueExercises[i]
            
            // Find Superset ID via the first set's routineItem
            let currentSet = session.sets.first(where: { $0.exercise == currentEx })
            let currentSupersetID = currentSet?.routineItem?.supersetID
            
            if let id = currentSupersetID {
                // Look ahead for others with same ID
                var supersetBuffer: [Exercise] = [currentEx]
                var j = i + 1
                while j < uniqueExercises.count {
                    let nextEx = uniqueExercises[j]
                    let nextSet = session.sets.first(where: { $0.exercise == nextEx })
                    if nextSet?.routineItem?.supersetID == id {
                        supersetBuffer.append(nextEx)
                        j += 1
                    } else {
                        break
                    }
                }
                groups.append(.superset(supersetBuffer))
                i = j
            } else {
                groups.append(.single(currentEx))
                i += 1
            }
        }
        return groups
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
    
    // MARK: - REORDER LOGIC
    private func moveExercise(_ exercise: Exercise, direction: Int) {
        guard let session = viewModel.currentSession else { return }
        
        var currentOrder = getExercises(from: session)
        guard let currentIndex = currentOrder.firstIndex(of: exercise) else { return }
        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < currentOrder.count else { return }
        
        withAnimation {
            currentOrder.swapAt(currentIndex, newIndex)
            
            // Re-assign global orderIndex
            var globalSetIndex = 0
            for ex in currentOrder {
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
            .tint(.green)
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
    
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    
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
