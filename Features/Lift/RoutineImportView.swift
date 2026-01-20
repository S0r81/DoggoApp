//
//  RoutineImportView.swift
//  Doggo
//
//  Created by Sorest on 1/19/26.
//

import SwiftUI
import SwiftData

struct RoutineImportView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // Data Source
    @Query var allExercises: [Exercise]
    
    // State
    @State private var isProcessing = false
    @State private var showFilePicker = false
    @State private var errorMessage: String?
    
    // The "Draft" Results
    @State private var importedRoutines: [AIImportedRoutine] = []
    
    private let manager = GeminiManager()
    
    var body: some View {
        NavigationStack {
            VStack {
                if isProcessing {
                    loadingView
                } else if !importedRoutines.isEmpty {
                    reviewList
                } else {
                    emptyState
                }
            }
            .navigationTitle("Import Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                if !importedRoutines.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save All") { saveAll() }
                            .bold()
                    }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker { url in
                    handleFileSelection(url)
                }
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Views
    
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Import from File")
                .font(.title2).bold()
            
            Text("Upload a PDF or Text file containing your workout plan. The AI will read it and map it to your exercises.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button(action: { showFilePicker = true }) {
                Label("Select File", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            
            Text("Supported: PDF, TXT")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("Reading File...")
                .font(.headline)
            Text("Mapping exercises to your database...")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    
    var reviewList: some View {
        List {
            ForEach(importedRoutines) { routine in
                Section(header: Text(routine.routineName)) {
                    ForEach(routine.exercises) { item in
                        HStack(alignment: .top, spacing: 12) {
                            
                            // MARK: - VISUAL INDICATOR (Superset)
                            if let label = item.supersetLabel {
                                VStack(spacing: 0) {
                                    Text(label)
                                        .font(.caption2).bold()
                                        .foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Circle().fill(Color.pink))
                                    
                                    // Connection Line
                                    Rectangle()
                                        .fill(Color.pink.opacity(0.3))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                }
                            } else {
                                // Spacer to keep alignment consistent
                                Color.clear.frame(width: 20)
                            }
                            
                            // Status Icon
                            statusIcon(for: item.confidence)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                // Name Display
                                if item.confidence == "None" {
                                    Text(item.originalName)
                                        .font(.headline)
                                    Text("New Exercise")
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .cornerRadius(4)
                                } else {
                                    Text(item.mappedName)
                                        .font(.headline)
                                    if item.originalName != item.mappedName {
                                        Text("Matches: \"\(item.originalName)\"")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                
                                // Sets/Reps
                                HStack {
                                    Text("\(item.sets) x \(item.reps)")
                                        .font(.caption).bold()
                                        .padding(4)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(4)
                                    
                                    if let note = item.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption).foregroundStyle(.orange)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .listRowSeparator(.hidden) // Cleaner look for groups
                    }
                }
            }
        }
    }
    
    func statusIcon(for confidence: String) -> some View {
        switch confidence {
        case "High":
            return Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case "Medium":
            return Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        default:
            return Image(systemName: "plus.circle.fill").foregroundStyle(.blue)
        }
    }
    
    // MARK: - Logic
    
    func handleFileSelection(_ url: URL) {
        print("▶️ handleFileSelection Triggered with URL: \(url)")
        isProcessing = true
        
        // 1. Extract Text (The Miner)
        guard let text = TextExtractor.extractText(from: url) else {
            print("❌ Text Extraction Failed")
            errorMessage = "Could not read text from this file."
            isProcessing = false
            return
        }
        
        print("✅ Text Extracted (First 50 chars): \(text.prefix(50))")
        
        // 2. Parse with AI (The Translator)
        Task {
            do {
                print("🤖 Sending to Gemini...")
                let drafts = try await manager.parseRoutineFromText(text, validExercises: allExercises)
                await MainActor.run {
                    print("✅ Received \(drafts.count) routines from AI")
                    self.importedRoutines = drafts
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    print("❌ AI Error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
    
    func saveAll() {
        for draftRoutine in importedRoutines {
            // 1. Create Routine
            let newRoutine = Routine(name: draftRoutine.routineName)
            modelContext.insert(newRoutine)
            
            // Map labels (e.g. "A") to UUIDs
            var supersetMap: [String: UUID] = [:]
            
            for (index, item) in draftRoutine.exercises.enumerated() {
                
                // 1b. Resolve Superset ID
                var finalSupersetID: UUID? = nil
                if let label = item.supersetLabel {
                    if let existingID = supersetMap[label] {
                        finalSupersetID = existingID
                    } else {
                        let newID = UUID()
                        supersetMap[label] = newID
                        finalSupersetID = newID
                    }
                }
                
                // 2. Resolve Exercise
                let exerciseToUse: Exercise
                
                if item.isNewExercise {
                    // Create NEW exercise
                    let newEx = Exercise(name: item.originalName)
                    modelContext.insert(newEx)
                    exerciseToUse = newEx
                } else {
                    // Find EXISTING exercise
                    if let match = allExercises.first(where: { $0.name == item.mappedName }) {
                        exerciseToUse = match
                    } else {
                        // Fallback
                        let fallback = Exercise(name: item.mappedName)
                        modelContext.insert(fallback)
                        exerciseToUse = fallback
                    }
                }
                
                // 3. Create Routine Item (NOW WITH SUPERSET ID)
                let routineItem = RoutineItem(
                    orderIndex: index,
                    exercise: exerciseToUse,
                    note: item.note,
                    supersetID: finalSupersetID // <--- Passed here
                )
                routineItem.routine = newRoutine
                modelContext.insert(routineItem)
                
                // 4. Create Sets (Blueprint)
                // Parse reps string to Int (e.g. "10-12" -> 10)
                // We strip non-numeric characters to find the first number
                let repsDigits = item.reps.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                let targetRepsInt = Int(repsDigits.prefix(2)) ?? 10 // simple fallback
                
                for i in 0..<item.sets {
                    let template = RoutineSetTemplate(orderIndex: i, targetReps: targetRepsInt)
                    template.routineItem = routineItem
                    modelContext.insert(template)
                }
            }
        }
        
        // Done
        dismiss()
    }
}
