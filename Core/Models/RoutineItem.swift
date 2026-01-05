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
    
    // NEW: The blueprint sets for this specific exercise in this routine
    @Relationship(deleteRule: .cascade, inverse: \RoutineSetTemplate.routineItem)
    var templateSets: [RoutineSetTemplate] = []
    
    init(orderIndex: Int, exercise: Exercise) {
        self.orderIndex = orderIndex
        self.exercise = exercise
    }
}
