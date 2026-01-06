//
//  DashboardViewModel.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation
import SwiftData

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
    
    // MARK: - Chart Data Logic
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
                
                if preferredUnit == "imperial" {
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
        if totalVolume > 1000 {
            return String(format: "%.1fk %@", totalVolume / 1000, preferredUnit == "imperial" ? "lbs" : "kg")
        } else {
            return "\(Int(totalVolume)) \(preferredUnit == "imperial" ? "lbs" : "kg")"
        }
    }
}
