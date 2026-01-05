//
//  Exercise.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation
import SwiftData

@Model
class Exercise {
    var id: UUID
    var name: String
    var muscleGroup: String // e.g., "Chest", "Legs"
    var type: String // "Strength", "Cardio"
    
    // Relationship: One exercise is used in many sets
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet] = []
    
    init(name: String, muscleGroup: String, type: String = "Strength") {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.type = type
    }
}
