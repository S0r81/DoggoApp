//
//  ActiveWorkoutViewModel.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
class ActiveWorkoutViewModel {
    var currentSession: WorkoutSession?
    
    var elapsedSeconds: Int = 0
    var isTimerRunning = false
    private var timer: Timer?
    var modelContext: ModelContext?
    
    init() {
        // We will load the active session in 'onAppear' via the View
        // because we need the ModelContext which isn't available in init()
    }
    
    // MARK: - Intelligent Start
    
    // 1. Check if we already have an unfinished workout
    func checkForActiveSession(context: ModelContext) {
        self.modelContext = context
        
        // Fetch the most recent incomplete session
        // (This is a manual fetch because @Query doesn't work inside classes easily)
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        if let existingSession = try? context.fetch(descriptor).first {
            print("Found existing active session!")
            resumeSession(existingSession)
        }
    }
    
    // 2. Start from a Routine Template
    func startWorkout(from routine: Routine, context: ModelContext) {
        self.modelContext = context
        
        let newSession = WorkoutSession(name: routine.name)
        context.insert(newSession)
        
        // 1. Get ordered items (Exercises)
        let sortedItems = routine.items.sorted { $0.orderIndex < $1.orderIndex }
        
        for item in sortedItems {
            if let exercise = item.exercise {
                // 2. Get ordered Sets for this exercise
                let sortedTemplates = item.templateSets.sorted { $0.orderIndex < $1.orderIndex }
                
                if sortedTemplates.isEmpty {
                    // Fallback: If they deleted all sets in the creator, add 1 empty set
                    let set = WorkoutSet(weight: 0, reps: 0, orderIndex: 1)
                    set.exercise = exercise
                    set.workoutSession = newSession
                    context.insert(set)
                } else {
                    // 3. Create real sets based on the template
                    for (index, template) in sortedTemplates.enumerated() {
                        let realSet = WorkoutSet(weight: 0, reps: template.targetReps, orderIndex: index + 1)
                        realSet.exercise = exercise
                        realSet.workoutSession = newSession
                        // Note: We don't copy weight because weight changes every session.
                        // (Unless you want to copy the weight from the LAST time you did this exercise, which is an advanced feature for later).
                        context.insert(realSet)
                    }
                }
            }
        }
        
        self.currentSession = newSession
        self.startTimer()
    }
    
    // 3. Start Empty
    func startNewWorkout(context: ModelContext) {
        self.modelContext = context
        let newSession = WorkoutSession(name: "Freestyle Workout")
        context.insert(newSession)
        self.currentSession = newSession
        self.startTimer()
    }
    
    // MARK: - Session Management
    
    func addSet(to exercise: Exercise, weight: Double, reps: Int) {
        guard let session = currentSession, let context = modelContext else { return }
        
        let nextIndex = session.sets.filter { $0.exercise == exercise }.count + 1
        let newSet = WorkoutSet(weight: weight, reps: reps, orderIndex: nextIndex)
        
        newSet.exercise = exercise
        newSet.workoutSession = session
        context.insert(newSet)
    }
    
    func deleteSet(_ set: WorkoutSet) {
        modelContext?.delete(set)
    }
    
    func finishWorkout() {
        guard let session = currentSession else { return }
        session.isCompleted = true
        session.duration = TimeInterval(elapsedSeconds)
        stopTimer()
        currentSession = nil
    }
    
    private func resumeSession(_ session: WorkoutSession) {
        self.currentSession = session
        // Calculate how long it's been since start (simplified)
        let gap = Date().timeIntervalSince(session.date)
        self.elapsedSeconds = Int(gap)
        startTimer()
    }
    
    private func startTimer() {
        stopTimer() // Safety check
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.elapsedSeconds += 1
        }
    }
    
    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
        elapsedSeconds = 0
    }
}
