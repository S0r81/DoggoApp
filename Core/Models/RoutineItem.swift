//
//  RoutineItem.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation
import SwiftData

@Model
class RoutineItem {
    var orderIndex: Int
    @Relationship var exercise: Exercise?
    var routine: Routine?
    
    // NEW: The instruction from the AI (e.g., "Aim for 135lbs")
    var note: String?
    
    // The blueprint sets for this specific exercise in this routine
    @Relationship(deleteRule: .cascade, inverse: \RoutineSetTemplate.routineItem)
    var templateSets: [RoutineSetTemplate] = []
    
    // Updated Init to include 'note'
    init(orderIndex: Int, exercise: Exercise, note: String? = nil) {
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.note = note
    }
}
