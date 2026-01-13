//
//  DashboardViewModel.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation
import SwiftData

// MARK: - Helper Structs for UI
struct ExerciseStat: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct BestLift: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let unit: String
    let date: Date
}

@Observable
class DashboardViewModel {
    
    // MARK: - Greeting Logic
    var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    // MARK: - Weekly Chart Data Logic
    struct DailyCount: Identifiable {
        let id = UUID()
        let day: String
        let count: Int
        let date: Date // For sorting/checking
    }
    
    func getWeeklyActivity(from sessions: [WorkoutSession]) -> [DailyCount] {
        var result: [DailyCount] = []
        let calendar = Calendar.current
        let today = Date()
        
        // Get the last 7 days (including today)
        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                // Find sessions on this specific date
                let count = sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
                
                // Format day name (e.g., "Mon", "Tue")
                let formatter = DateFormatter()
                formatter.dateFormat = "E"
                let dayName = formatter.string(from: date)
                
                result.append(DailyCount(day: dayName, count: count, date: date))
            }
        }
        return result
    }
    
    // MARK: - New Stats Logic
    
    func getTotalDuration(from sessions: [WorkoutSession]) -> String {
        let totalSeconds = sessions.reduce(0) { $0 + $1.duration }
        let hours = totalSeconds / 3600
        return String(format: "%.1f hrs", hours)
    }
    
    func getCurrentStreak(from sessions: [WorkoutSession]) -> Int {
        // 1. Get unique days with workouts, sorted newest to oldest
        let calendar = Calendar.current
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        let sortedDays = uniqueDays.sorted(by: >)
        
        guard let lastWorkoutDay = sortedDays.first else { return 0 }
        
        // 2. Check if the streak is still "alive" (workout today or yesterday)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        if lastWorkoutDay != today && lastWorkoutDay != yesterday {
            return 0
        }
        
        // 3. Count backwards
        var streak = 0
        var checkDate = lastWorkoutDay
        
        for day in sortedDays {
            if calendar.isDate(day, inSameDayAs: checkDate) {
                streak += 1
                // Move checkDate back one day
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Volume Logic (True Unit Support)
    func getTotalVolume(from sessions: [WorkoutSession], preferredUnit: String) -> String {
        var totalVolume: Double = 0
        
        for session in sessions {
            for set in session.sets {
                // Skip cardio
                guard set.distance == nil else { continue }
                
                let weight = set.weight
                let reps = Double(set.reps)
                
                // Normalize to Preferred Unit
                var normalizedWeight = weight
                
                // "imperial" string usually comes from the rawValue of UnitSystem enum.
                // Depending on how you stored it, checking for "imperial" or "lbs" is safer.
                // Assuming UnitSystem.imperial.rawValue == "imperial"
                
                if preferredUnit == "imperial" || preferredUnit == "lbs" {
                    // We want LBS. If set is KG, convert.
                    if set.unit == "kg" { normalizedWeight = weight * 2.20462 }
                } else {
                    // We want KG. If set is LBS, convert.
                    if set.unit == "lbs" { normalizedWeight = weight * 0.453592 }
                }
                
                totalVolume += (normalizedWeight * reps)
            }
        }
        
        // Format nicely (e.g. "12k lbs")
        let suffix = (preferredUnit == "imperial" || preferredUnit == "lbs") ? "lbs" : "kg"
        
        if totalVolume > 1000000 {
             return String(format: "%.1fM %@", totalVolume / 1000000, suffix)
        } else if totalVolume > 1000 {
            return String(format: "%.1fk %@", totalVolume / 1000, suffix)
        } else {
            return "\(Int(totalVolume)) \(suffix)"
        }
    }
    
    // MARK: - New: Top Exercises (Donut Chart)
    func getTopExercises(from sessions: [WorkoutSession]) -> [ExerciseStat] {
        var counts: [String: Int] = [:]
        
        for session in sessions {
            for set in session.sets {
                guard let name = set.exercise?.name else { continue }
                counts[name, default: 0] += 1
            }
        }
        
        // Sort by frequency
        let sorted = counts.map { ExerciseStat(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        // Return top 5
        return Array(sorted.prefix(5))
    }
    
    // MARK: - New: Recent Best Lifts (Carousel)
    func getRecentBests(from sessions: [WorkoutSession]) -> [BestLift] {
        var bests: [String: BestLift] = [:]
        
        // Look at last 10 sessions to find heavy lifts
        for session in sessions.prefix(10) {
            for set in session.sets {
                guard let name = set.exercise?.name, set.weight > 0 else { continue }
                
                // If we haven't seen this exercise yet, or this set is heavier than the stored one
                if let currentBest = bests[name] {
                    if set.weight > currentBest.weight {
                        bests[name] = BestLift(exerciseName: name, weight: set.weight, unit: set.unit, date: session.date)
                    }
                } else {
                    bests[name] = BestLift(exerciseName: name, weight: set.weight, unit: set.unit, date: session.date)
                }
            }
        }
        
        // Return the lifts, sorted by weight descending (just for display purposes)
        // Taking top 5 heaviest distinct exercises found recently
        return Array(bests.values.sorted { $0.weight > $1.weight }.prefix(5))
    }
}
