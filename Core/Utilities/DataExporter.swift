//
//  DataExporter.swift
//  Doggo
//
//  Created by Sorest on 1/13/26.
//

import Foundation
import SwiftData

struct DataExporter {
    
    static func generateCSV(from sessions: [WorkoutSession]) -> String {
        // Updated Header to be explicit about what we are exporting
        var csvString = "Date,Workout Name,Duration (min),Exercise,Set,Weight,Reps,Distance,Time,Unit\n"
        
        for session in sessions {
            // FIX: Now includes Time (e.g. "1/13/2026, 5:30 PM")
            let date = session.date.formatted(date: .numeric, time: .shortened).replacingOccurrences(of: ",", with: "")
            
            let workoutName = clean(session.name)
            let durationMin = String(format: "%.1f", session.duration / 60)
            
            let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
            
            for set in sortedSets {
                guard let exercise = set.exercise else { continue }
                
                let exerciseName = clean(exercise.name)
                let setNumber = set.orderIndex
                
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
                
                let row = "\(date),\(workoutName),\(durationMin),\(exerciseName),\(setNumber),\(weight),\(reps),\(distance),\(time),\(unit)\n"
                csvString.append(row)
            }
        }
        return csvString
    }
    
    static func createCSVFile(from sessions: [WorkoutSession]) -> URL? {
        let csvData = generateCSV(from: sessions)
        let fileName = "Doggo_Workouts_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).csv"
        
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
    
    private static func clean(_ text: String) -> String {
        return text.replacingOccurrences(of: ",", with: " ")
    }
}
