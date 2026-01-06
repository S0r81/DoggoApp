//
//  Exercise.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftData
import Foundation

@Model
class Exercise {
    var id: UUID
    var name: String
    var type: String // "Strength" or "Cardio"
    var muscleGroup: String // <--- NEW PROPERTY
    
    @Relationship(deleteRule: .cascade)
    var sets: [WorkoutSet] = []
    
    // Updated Initializer
    init(name: String, type: String = "Strength", muscleGroup: String = "Other") {
        self.id = UUID()
        self.name = name
        self.type = type
        self.muscleGroup = muscleGroup
    }
}
