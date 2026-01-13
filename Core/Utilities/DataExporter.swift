//
//  DataExporter.swift
//  Doggo
//
//  Created by Sorest on 1/13/26.
//

import Foundation
import SwiftData

struct DataExporter {
    
    /// Generates a CSV String from the provided sessions
    static func generateCSV(from sessions: [WorkoutSession]) -> String {
        // 1. Define the Header Row
        var csvString = "Date,Workout Name,Duration (min),Exercise,Set,Weight,Reps,Distance,Time,Unit\n"
        
        // 2. Loop through every session
        for session in sessions {
            let date = session.date.formatted(date: .numeric, time: .omitted) // "1/13/2026"
            let workoutName = clean(session.name)
            let durationMin = String(format: "%.1f", session.duration / 60)
            
            // Sort sets so they appear in order
            let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
            
            for set in sortedSets {
                guard let exercise = set.exercise else { continue }
                
                let exerciseName = clean(exercise.name)
                let setNumber = set.orderIndex
                
                // Handle Weight/Reps vs Cardio
                var weight = ""
                var reps = ""
                var distance = ""
                var time = ""
                
                if exercise.type == "Cardio" {
                    distance = String(set.distance ?? 0)
                    time = String(set.duration ?? 0)
                } else {
                    weight = String(set.weight)
                    reps = String(set.reps)
                }
                
                let unit = set.unit
                
                // 3. Create the row
                let row = "\(date),\(workoutName),\(durationMin),\(exerciseName),\(setNumber),\(weight),\(reps),\(distance),\(time),\(unit)\n"
                
                csvString.append(row)
            }
        }
        return csvString
    }
    
    /// Helper to create a temporary file URL for sharing
    static func createCSVFile(from sessions: [WorkoutSession]) -> URL? {
        let csvData = generateCSV(from: sessions)
        let fileName = "Doggo_Workouts_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).csv"
        
        // Save to temporary directory
        if let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = path.appendingPathComponent(fileName)
            
            do {
                try csvData.write(to: fileURL, atomically: true, encoding: .utf8)
                return fileURL
            } catch {
                print("Error creating CSV file: \(error)")
                return nil
            }
        }
        return nil
    }
    
    // Helper to remove commas from text so they don't break the CSV
    private static func clean(_ text: String) -> String {
        return text.replacingOccurrences(of: ",", with: " ")
    }
}
