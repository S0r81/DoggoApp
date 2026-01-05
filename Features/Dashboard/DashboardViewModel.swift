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
    
    init() { }
    
    // MARK: - Logic
    
    /// Determines the greeting based on the current hour (24h format)
    var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Hello Night Owl"
        }
    }
    
    /// Filters the provided sessions to find only ones from the current week
    func getWorkoutsThisWeek(from sessions: [WorkoutSession]) -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        // Find the Monday (or start) of the current week
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return 0
        }
        
        return sessions.filter { $0.date >= startOfWeek }.count
    }
}
