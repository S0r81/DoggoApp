import Foundation
import SwiftData
import SwiftUI
import UIKit
import ActivityKit

@Observable
class ActiveWorkoutViewModel {
    var currentSession: WorkoutSession?
    
    // Live Activity Reference
    var currentActivity: Activity<DoggoActivityAttributes>?
    
    // Main Workout Timer
    var elapsedSeconds: Int = 0
    var isTimerRunning = false
    private var timer: Timer?
    var modelContext: ModelContext?
    
    // MARK: - Rest Timer State
    var restTimer: Timer?
    var restSecondsRemaining = 0
    var isRestTimerActive = false
    
    // NEW: The "Source of Truth" for sync
    // We store exactly when the timer should finish.
    var restTimerEndTime: Date?
    
    let fallbackRestTime = 90
    
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
        
        var globalOrderIndex = 0
        let savedUnit = UserDefaults.standard.string(forKey: "unitSystem")
        let isMetric = (savedUnit == "metric")
        
        for item in sortedItems {
            if let exercise = item.exercise {
                let sortedTemplates = item.templateSets.sorted { $0.orderIndex < $1.orderIndex }
                
                var unitForThisExercise = "lbs"
                if exercise.type == "Cardio" {
                    unitForThisExercise = isMetric ? "km" : "mi"
                } else {
                    unitForThisExercise = isMetric ? "kg" : "lbs"
                }
                
                if sortedTemplates.isEmpty {
                    globalOrderIndex += 1
                    let set = WorkoutSet(weight: 0, reps: 0, orderIndex: globalOrderIndex, unit: unitForThisExercise)
                    set.exercise = exercise
                    set.workoutSession = newSession
                    context.insert(set)
                } else {
                    for template in sortedTemplates {
                        globalOrderIndex += 1
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
        
        let highestIndex = session.sets.map { $0.orderIndex }.max() ?? 0
        let nextIndex = highestIndex + 1
        
        let savedUnit = UserDefaults.standard.string(forKey: "unitSystem")
        let isMetric = (savedUnit == "metric")
        
        var unitToUse = "lbs"
        if exercise.type == "Cardio" {
            unitToUse = isMetric ? "km" : "mi"
        } else {
            unitToUse = isMetric ? "kg" : "lbs"
        }
        
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
        cancelRestTimer()
        currentSession = nil
    }
    
    // MARK: - Main Workout Timer
    
    private func resumeSession(_ session: WorkoutSession) {
        self.currentSession = session
        // Calculate gap immediately based on Dates
        if let start = session.startTime {
            self.elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
        startTimer()
    }
    
    private func startTimer() {
        stopTimer()
        if currentSession?.startTime == nil { currentSession?.startTime = Date() }
        guard let start = currentSession?.startTime else { return }
        
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            // Logic: Compare NOW with START. This creates a self-correcting timer.
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
    
    // MARK: - Rest Timer Logic (Sync Fix)
    
    func startRestTimer() {
        cancelRestTimer()
        
        let savedSeconds = UserDefaults.standard.integer(forKey: "defaultRestSeconds")
        let duration = (savedSeconds == 0) ? fallbackRestTime : savedSeconds
        
        // 1. Set the Source of Truth (Future Date)
        let finishDate = Date().addingTimeInterval(Double(duration))
        self.restTimerEndTime = finishDate
        
        // 2. Update immediate UI
        self.restSecondsRemaining = duration
        self.isRestTimerActive = true
        
        // 3. Start In-App Loop (Checks Date instead of just decrementing)
        // We check every 0.1s to make the UI feel snappy
        restTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateRestTimer()
        }
        
        // 4. Start Live Activity
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = DoggoActivityAttributes()
            let contentState = DoggoActivityAttributes.ContentState(endTime: finishDate)
            
            do {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: contentState, staleDate: nil)
                )
            } catch {
                print("Error starting Live Activity: \(error.localizedDescription)")
            }
        }
    }
    
    // NEW: Helper to sync the timer
    private func updateRestTimer() {
        guard let endTime = restTimerEndTime else { return }
        let remaining = endTime.timeIntervalSince(Date())
        
        if remaining > 0 {
            // Update UI with actual remaining time
            // We add 1 so that 29.9 seconds shows as "30" rather than "29"
            self.restSecondsRemaining = Int(remaining) + 1
        } else {
            // Timer Finished
            cancelRestTimer()
            HapticManager.shared.notification(type: .success)
        }
    }
    
    func cancelRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isRestTimerActive = false
        restSecondsRemaining = 0
        restTimerEndTime = nil
        
        // End Live Activity
        if let activity = currentActivity {
            // Updated for iOS 16.2 deprecation
            let finalState = DoggoActivityAttributes.ContentState(endTime: Date())
            let finalContent = ActivityContent(state: finalState, staleDate: nil)
            
            Task {
                await activity.end(finalContent, dismissalPolicy: .immediate)
                currentActivity = nil
            }
        }
    }
    
    func addRestTime(_ seconds: Int) {
        // 1. Update the Source of Truth
        guard let oldEndTime = restTimerEndTime else { return }
        let newEndTime = oldEndTime.addingTimeInterval(Double(seconds))
        self.restTimerEndTime = newEndTime
        
        // 2. Force immediate UI update
        updateRestTimer()
        
        // 3. Update Live Activity
        if let activity = currentActivity {
            let updatedState = DoggoActivityAttributes.ContentState(endTime: newEndTime)
            Task {
                await activity.update(
                    ActivityContent(state: updatedState, staleDate: nil)
                )
            }
        }
    }
}
