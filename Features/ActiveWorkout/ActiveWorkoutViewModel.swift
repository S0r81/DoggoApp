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
    
    init() { }
    
    // MARK: - Start & Resume
    
    func checkForActiveSession(context: ModelContext) {
        self.modelContext = context
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let existingSession = try? context.fetch(descriptor).first {
            resumeSession(existingSession)
        }
    }
    
    func startNewWorkout(context: ModelContext) {
        self.modelContext = context
        let newSession = WorkoutSession(name: "Freestyle Workout")
        newSession.startTime = Date()
        context.insert(newSession)
        self.currentSession = newSession
        self.startTimer()
    }
    
    func startWorkout(from routine: Routine, context: ModelContext) {
        self.modelContext = context
        let newSession = WorkoutSession(name: routine.name)
        newSession.startTime = Date()
        context.insert(newSession)
        
        let sortedItems = routine.items.sorted { $0.orderIndex < $1.orderIndex }
        
        // GLOBAL COUNTER
        var globalOrderIndex = 0
        
        // 1. Check User Preference ONCE at the start
        let savedUnit = UserDefaults.standard.string(forKey: "unitSystem")
        let isMetric = (savedUnit == "metric")
        
        for item in sortedItems {
            if let exercise = item.exercise {
                let sortedTemplates = item.templateSets.sorted { $0.orderIndex < $1.orderIndex }
                
                // 2. Determine Unit for this specific exercise
                var unitForThisExercise = "lbs"
                if exercise.type == "Cardio" {
                    unitForThisExercise = isMetric ? "km" : "mi"
                } else {
                    unitForThisExercise = isMetric ? "kg" : "lbs"
                }
                
                if sortedTemplates.isEmpty {
                    globalOrderIndex += 1
                    // Create empty set with CORRECT UNIT
                    let set = WorkoutSet(weight: 0, reps: 0, orderIndex: globalOrderIndex, unit: unitForThisExercise)
                    set.exercise = exercise
                    set.workoutSession = newSession
                    context.insert(set)
                } else {
                    for template in sortedTemplates {
                        globalOrderIndex += 1
                        // Create template set with CORRECT UNIT
                        let realSet = WorkoutSet(weight: 0, reps: template.targetReps, orderIndex: globalOrderIndex, unit: unitForThisExercise)
                        realSet.exercise = exercise
                        realSet.workoutSession = newSession
                        context.insert(realSet)
                    }
                }
            }
        }
        self.currentSession = newSession
        self.startTimer()
    }
    
    // MARK: - Set Management
    
    func addSet(to exercise: Exercise, weight: Double, reps: Int) {
        guard let session = currentSession, let context = modelContext else { return }
        
        // 1. Find highest ID
        let highestIndex = session.sets.map { $0.orderIndex }.max() ?? 0
        let nextIndex = highestIndex + 1
        
        // 2. Check User Preference
        let savedUnit = UserDefaults.standard.string(forKey: "unitSystem")
        let isMetric = (savedUnit == "metric")
        
        // 3. Determine Unit
        var unitToUse = "lbs"
        if exercise.type == "Cardio" {
            unitToUse = isMetric ? "km" : "mi"
        } else {
            unitToUse = isMetric ? "kg" : "lbs"
        }
        
        // 4. Create
        let newSet = WorkoutSet(weight: weight, reps: reps, orderIndex: nextIndex, unit: unitToUse)
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
    
    // MARK: - Timer
    
    private func resumeSession(_ session: WorkoutSession) {
        self.currentSession = session
        if let start = session.startTime {
            let gap = Date().timeIntervalSince(start)
            self.elapsedSeconds = Int(gap)
        } else {
            let gap = Date().timeIntervalSince(session.date)
            self.elapsedSeconds = Int(gap)
        }
        startTimer()
    }
    
    private func startTimer() {
        stopTimer()
        if currentSession?.startTime == nil { currentSession?.startTime = Date() }
        guard let start = currentSession?.startTime else { return }
        
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let diff = Date().timeIntervalSince(start)
            self?.elapsedSeconds = Int(diff)
        }
    }
    
    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
        elapsedSeconds = 0
    }
}
