//
//  SetRowView.swift
//  Doggo
//
//  Created by Sorest on 1/20/26.
//

import SwiftUI
import SwiftData

struct SetRowView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var set: WorkoutSet
    var index: Int
    var onComplete: () -> Void
    
    // Data for AI Context
    @Query var profiles: [UserProfile]
    
    // UI State
    @State private var showWeightPicker = false
    @State private var showRepsPicker = false
    
    // AI State
    @State private var isSuggesting = false
    @State private var suggestionNote: String? // Shows the "Why"
    
    private let manager = GeminiManager()
    
    // Range Logic
    var weightOptions: [Double] {
        if set.unit == "kg" {
            return Array(stride(from: 0, through: 300, by: 1.0))
        } else {
            return Array(stride(from: 0, through: 600, by: 2.5))
        }
    }
    let repsOptions: [Int] = Array(0...100)
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // 1. Set Number
                Text("\(index)")
                    .font(.caption).bold()
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                
                // 2. NEW: Explicit Magic Wand Button
                if isSuggesting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 24, height: 24)
                } else {
                    Button(action: { getSmartSuggestion() }) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.purple)
                            .frame(width: 24, height: 24)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                // 3. Weight Input
                HStack(spacing: 0) {
                    Button(action: { showWeightPicker = true }) {
                        Text("\(set.weight, format: .number)")
                            .font(.title3).fontWeight(.bold)
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                    }
                    .sheet(isPresented: $showWeightPicker) {
                        weightPickerSheet
                    }
                    
                    Menu {
                        Button("lbs") { set.unit = "lbs" }
                        Button("kg") { set.unit = "kg" }
                    } label: {
                        Text(set.unit)
                            .font(.caption2).foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.1)).cornerRadius(4)
                    }
                    .padding(.trailing, 6)
                }
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
                
                // 4. Reps Input
                Button(action: { showRepsPicker = true }) {
                    VStack(spacing: 2) {
                        Text("\(set.reps)")
                            .font(.title3).fontWeight(.bold).foregroundStyle(.blue)
                        Text("reps").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 60)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showRepsPicker) {
                    repsPickerSheet
                }
                
                // 5. Completion Checkbox
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    withAnimation(.snappy) { set.isCompleted.toggle() }
                    if set.isCompleted { onComplete() }
                }) {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundStyle(set.isCompleted ? .green : .gray.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            
            // Suggestion Note (Toast)
            if let note = suggestionNote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 50) // Indent to align with inputs
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Picker Sheets
    var weightPickerSheet: some View {
        VStack {
            Text("Select Weight (\(set.unit))").font(.headline).padding(.top)
            Picker("Weight", selection: $set.weight) {
                ForEach(weightOptions, id: \.self) { w in
                    Text("\(w, format: .number)").tag(w)
                }
            }
            .pickerStyle(.wheel).labelsHidden()
        }
        .presentationDetents([.fraction(0.3)]).presentationDragIndicator(.visible)
    }
    
    var repsPickerSheet: some View {
        VStack {
            Text("Select Reps").font(.headline).padding(.top)
            Picker("Reps", selection: $set.reps) {
                ForEach(repsOptions, id: \.self) { r in
                    Text("\(r) reps").tag(r)
                }
            }
            .pickerStyle(.wheel).labelsHidden()
        }
        .presentationDetents([.fraction(0.3)]).presentationDragIndicator(.visible)
    }
    
    // MARK: - AI Logic
    
    private func getSmartSuggestion() {
        guard let exercise = set.exercise else { return }
        let goal = profiles.first?.fitnessGoal ?? "General Fitness"
        
        isSuggesting = true
        suggestionNote = nil // Clear old note
        
        Task {
            // 1. Fetch History (Last 5 completed sessions containing this exercise)
            let descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate<WorkoutSession> { session in
                    session.isCompleted == true
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            var historyData: [HistoryContext] = []
            
            if let recentSessions = try? modelContext.fetch(descriptor) {
                for session in recentSessions.prefix(20) {
                    let relevantSets = session.sets.filter { $0.exercise?.id == exercise.id }
                    if let bestSet = relevantSets.max(by: { $0.weight < $1.weight }) {
                        historyData.append(HistoryContext(
                            date: session.date,
                            weight: bestSet.weight,
                            reps: bestSet.reps
                        ))
                    }
                    if historyData.count >= 5 { break }
                }
            }
            
            // 2. Call Gemini
            do {
                let suggestion = try await manager.getSetSuggestion(
                    exerciseName: exercise.name,
                    history: historyData.reversed(),
                    goal: goal
                )
                
                await MainActor.run {
                    withAnimation {
                        set.weight = suggestion.weight
                        set.reps = suggestion.reps
                        suggestionNote = "✨ Coach: \(suggestion.reasoning)"
                        isSuggesting = false
                    }
                    HapticManager.shared.notification(type: .success)
                }
            } catch {
                print("AI Suggestion Error: \(error)")
                await MainActor.run {
                    suggestionNote = "⚠️ Couldn't reach coach."
                    isSuggesting = false
                }
            }
        }
    }
}
