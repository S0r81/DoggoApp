import SwiftData
import Foundation

@Model
class WorkoutSet {
    var id: UUID
    var weight: Double
    var reps: Int
    var orderIndex: Int
    var isCompleted: Bool
    
    // NEW: Store the unit for this specific set
    // Defaults to "lbs" for migration safety
    var unit: String = "lbs"
    
    // Cardio specific
    var distance: Double?
    var duration: Double?
    
    @Relationship(inverse: \WorkoutSession.sets)
    var workoutSession: WorkoutSession?
    
    @Relationship(inverse: \Exercise.sets)
    var exercise: Exercise?
    
    init(weight: Double, reps: Int, orderIndex: Int, unit: String = "lbs") {
        self.id = UUID()
        self.weight = weight
        self.reps = reps
        self.orderIndex = orderIndex
        self.isCompleted = false
        self.unit = unit
    }
}
