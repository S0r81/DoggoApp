//
//  UserProfile.swift
//  Doggo
//
//  Created by Sorest on 1/14/26.
//

import Foundation
import SwiftData

@Model
class UserProfile {
    var name: String
    var age: Int
    var heightCM: Double // Storing standard units makes math easier
    var weightKG: Double
    var activityLevel: String // "Sedentary", "Active", "Athlete"
    var fitnessGoal: String   // "Build Muscle", "Lose Fat", "Strength", "Endurance"
    var experienceLevel: String // "Beginner", "Intermediate", "Advanced"
    
    // For unit preferences (optional, but good to store here)
    var useMetric: Bool = false
    
    init(name: String, age: Int, heightCM: Double, weightKG: Double, activityLevel: String, fitnessGoal: String, experienceLevel: String) {
        self.name = name
        self.age = age
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.activityLevel = activityLevel
        self.fitnessGoal = fitnessGoal
        self.experienceLevel = experienceLevel
    }
    
    // Helper for AI Context
    var aiDescription: String {
        return """
        USER PROFILE:
        - Name: \(name)
        - Age: \(age)
        - Stats: \(Int(heightCM))cm, \(Int(weightKG))kg
        - Level: \(experienceLevel)
        - Activity: \(activityLevel)
        - PRIMARY GOAL: \(fitnessGoal)
        """
    }
}
