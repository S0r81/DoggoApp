import SwiftUI
import SwiftData

struct RoutineGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // Data Sources
    @Query(sort: \WorkoutSession.date, order: .reverse) var history: [WorkoutSession]
    @Query var routines: [Routine]
    @Query var exercises: [Exercise]
    @Query(sort: \AIGeneratedRoutine.date, order: .reverse) var savedGenerations: [AIGeneratedRoutine] // HISTORY
    
    // NEW: Fetch User Profile for Personalization
    @Query var profiles: [UserProfile]
    
    // Inputs
    @State private var targetFocus: String = "Push"
    @State private var duration: Double = 60
    let focusOptions = ["Push", "Pull", "Legs", "Upper Body", "Full Body", "Cardio"]
    
    // Outputs
    @State private var isGenerating = false
    @State private var generatedRoutineName: String = ""
    @State private var generatedCandidates: [GenItem] = []
    @State private var showHistorySheet = false // For the history popup
    @State private var errorMessage: String?
    
    // Enhanced Struct for UI
    struct GenItem: Identifiable {
        let id = UUID()
        let name: String
        let sets: Int
        let reps: String
        let note: String
        var isSelected: Bool = true
    }
    
    private let manager = GeminiManager()
    
    var body: some View {
        NavigationStack {
            VStack {
                if isGenerating {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5)
                        Text("Constructing Routine...").font(.headline)
                        // Optional: Show personalization text
                        if let goal = profiles.first?.fitnessGoal {
                            Text("Optimizing for \(goal)...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                else if generatedCandidates.isEmpty {
                    inputForm // Step 1
                }
                else {
                    selectionList // Step 2
                }
            }
            .navigationTitle("AI Builder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                // HISTORY BUTTON (Only show on input screen)
                if generatedCandidates.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showHistorySheet = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                }
            }
            // HISTORY SHEET
            .sheet(isPresented: $showHistorySheet) {
                HistorySheet(savedGenerations: savedGenerations) { selectedDraft in
                    loadDraft(selectedDraft)
                }
            }
        }
    }
    
    // MARK: - Input Form
    var inputForm: some View {
        Form {
            Section("Focus") {
                // ... (Same Grid as before) ...
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                    ForEach(focusOptions, id: \.self) { option in
                        Button(action: { targetFocus = option }) {
                            Text(option)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.vertical, 8).padding(.horizontal, 12)
                                .frame(maxWidth: .infinity)
                                .background(targetFocus == option ? Color.blue : Color(uiColor: .secondarySystemBackground))
                                .foregroundStyle(targetFocus == option ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section("Duration") {
                HStack {
                    Image(systemName: "clock").foregroundStyle(.blue)
                    Slider(value: $duration, in: 15...120, step: 15)
                    Text("\(Int(duration)) min").monospacedDigit()
                }
            }
            Section {
                Button(action: generate) {
                    Label("Generate Options", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.blue)
                .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Selection List
    var selectionList: some View {
        List {
            Section("Routine Name") {
                TextField("Name", text: $generatedRoutineName).font(.headline)
            }
            Section {
                ForEach($generatedCandidates) { $item in
                    HStack(alignment: .top, spacing: 12) {
                        Button(action: { item.isSelected.toggle() }) {
                            Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                .font(.title2)
                                .foregroundStyle(item.isSelected ? .blue : .gray)
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                                .strikethrough(!item.isSelected)
                                .opacity(item.isSelected ? 1.0 : 0.5)
                            
                            // SHOW THE DETAILS
                            HStack {
                                Text("\(item.sets) sets x \(item.reps)")
                                    .font(.caption).bold()
                                    .padding(4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                                
                                Text(item.note)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                            .opacity(item.isSelected ? 1.0 : 0.5)
                        }
                    }
                }
            } header: { Text("Select Exercises") }
            
            Button("Save Routine", action: saveRoutine)
                .buttonStyle(.borderedProminent)
                .disabled(generatedCandidates.filter{ $0.isSelected }.isEmpty)
        }
    }
    
    // MARK: - Logic
    func generate() {
        withAnimation { isGenerating = true }
        
        Task {
            do {
                // 1. Get Result from AI
                // UPDATED: Pass the UserProfile here!
                let result = try await manager.generateRoutine(
                    history: history,
                    existingRoutines: routines,
                    availableExercises: exercises,
                    profile: profiles.first, // <--- NEW
                    focus: targetFocus,
                    duration: Int(duration)
                )
                
                await MainActor.run {
                    // 2. Save to History (SwiftData)
                    let draft = AIGeneratedRoutine(
                        focus: targetFocus,
                        duration: Int(duration),
                        routineName: result.name,
                        rawJSON: result.rawJSON
                    )
                    modelContext.insert(draft)
                    
                    // 3. Update UI
                    self.generatedRoutineName = result.name
                    self.generatedCandidates = result.items.map {
                        GenItem(name: $0.name, sets: $0.sets, reps: $0.reps, note: $0.note)
                    }
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }
    
    func saveRoutine() {
        let newRoutine = Routine(name: generatedRoutineName)
        modelContext.insert(newRoutine)
        
        let selectedItems = generatedCandidates.filter { $0.isSelected }
        
        for (index, item) in selectedItems.enumerated() {
            if let exerciseObj = exercises.first(where: { $0.name == item.name }) {
                // 1. Create RoutineItem
                let routineItem = RoutineItem(orderIndex: index, exercise: exerciseObj, note: item.note)
                routineItem.routine = newRoutine
                modelContext.insert(routineItem)
                
                // 2. Create the Template Sets
                for i in 0..<item.sets {
                    // Extract the number from string (e.g. "8-12" -> 8)
                    let repCount = Int(item.reps.components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "10") ?? 10
                    
                    // FIXED: Used 'orderIndex' and 'targetReps' to match your model
                    let template = RoutineSetTemplate(orderIndex: i, targetReps: repCount)
                    
                    template.routineItem = routineItem
                    modelContext.insert(template)
                }
            }
        }
        dismiss()
    }
    
    // Load a draft from history
    func loadDraft(_ draft: AIGeneratedRoutine) {
        showHistorySheet = false
        
        // Convert raw JSON back to items
        guard let data = draft.rawJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exercises = json["exercises"] as? [[String: Any]]
        else { return }
        
        self.generatedRoutineName = draft.routineName
        
        self.generatedCandidates = exercises.compactMap { dict in
            guard let name = dict["name"] as? String else { return nil }
            let sets = dict["sets"] as? Int ?? 3
            let reps = "\(dict["reps"] ?? "10")"
            let note = dict["note"] as? String ?? ""
            return GenItem(name: name, sets: sets, reps: reps, note: note)
        }
    }
}

// MARK: - Subview: History Sheet
struct HistorySheet: View {
    @Environment(\.dismiss) var dismiss
    let savedGenerations: [AIGeneratedRoutine]
    let onSelect: (AIGeneratedRoutine) -> Void
    
    var body: some View {
        NavigationStack {
            List(savedGenerations) { draft in
                Button(action: { onSelect(draft) }) {
                    VStack(alignment: .leading) {
                        Text(draft.routineName).font(.headline)
                        HStack {
                            Text(draft.focus).font(.caption).padding(4).background(Color.blue.opacity(0.1)).cornerRadius(4)
                            Text("\(draft.duration) min").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(draft.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Past Generations")
            .overlay {
                if savedGenerations.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock")
                }
            }
            .toolbar { Button("Close") { dismiss() } }
        }
    }
}
