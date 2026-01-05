import Foundation
import SwiftData

@Model
class WorkoutSet {
    var id: UUID
    var orderIndex: Int
    var isCompleted: Bool
    
    // STRENGTH FIELDS
    var weight: Double
    var reps: Int
    
    // CARDIO FIELDS (New!)
    var distance: Double? // e.g., Miles
    var duration: Double? // e.g., Minutes
    
    // The Parents
    var workoutSession: WorkoutSession?
    var exercise: Exercise?
    
    init(weight: Double = 0, reps: Int = 0, distance: Double? = nil, duration: Double? = nil, orderIndex: Int) {
        self.id = UUID()
        self.weight = weight
        self.reps = reps
        self.distance = distance
        self.duration = duration
        self.orderIndex = orderIndex
        self.isCompleted = false
    }
}
