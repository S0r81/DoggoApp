//
//  GeminiManager.swift
//  Doggo
//
//  Created by Sorest on 1/13/26.
//

import Foundation

// MARK: - Shared AI Models (Top Level to fix Scope Errors)
struct SetSuggestion: Decodable {
    let weight: Double
    let reps: Int
    let reasoning: String
}

struct HistoryContext {
    let date: Date
    let weight: Double
    let reps: Int
}

class GeminiManager {
    // YOUR WORKING KEY
    private let apiKey = "AIzaSyAz5YW_9mbgZ5Ty3TRxHea7G_UOzHbpt_0"
    
    // Gemini 2.0 Flash (High Rate Limit)
    private let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"
    
    // MARK: - Core Request (Public)
    func sendRequest(prompt: String) async throws -> String {
        guard let url = URL(string: "\(urlString)?key=\(apiKey)") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Timeout 180s
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                return "⚠️ The Coach is busy (Rate Limit). Please try again in a minute."
            }
            if httpResponse.statusCode != 200 {
                print("Gemini API Error: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            return text
        }
        
        throw URLError(.cannotParseResponse)
    }
    
    // MARK: - 1. Coach's Report
    func generateAnalysis(from sessions: [WorkoutSession], profile: UserProfile?) async throws -> String {
        print("--- DEBUG: Starting AI Analysis ---")
        
        let stats = calculateStats(from: sessions)
        let recentHistory = sessions.sorted { $0.date > $1.date }.prefix(10)
        var historyString = ""
        
        for session in recentHistory {
            let date = session.date.formatted(date: .numeric, time: .omitted)
            historyString += "- \(date): \(session.name) (\(Int(session.duration/60)) min)\n"
            
            let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
            let heavySets = sortedSets.filter { $0.weight > 0 }.prefix(8)
            
            for set in heavySets {
                if let name = set.exercise?.name {
                    historyString += "  * \(name): \(Int(set.weight)) \(set.unit) x \(set.reps)\n"
                }
            }
        }
        
        var userContext = "User Profile: Unknown"
        if let p = profile {
            userContext = """
            User Profile:
            - Goal: \(p.fitnessGoal)
            - Experience: \(p.experienceLevel)
            """
        }
        
        let prompt = """
        You are an elite strength and conditioning coach. Analyze this user's recent training data.
        
        \(userContext)
        
        QUANTITATIVE DATA (Last 30 Days):
        - Workout Consistency: \(stats.workoutsPerWeek) sessions/week
        - Avg Session Duration: \(stats.avgDuration)
        - Muscle Focus Split: \(stats.muscleSplit)
        - Total Volume: \(stats.totalVolume) lbs
        
        RECENT ACTIVITY LOG (Newest first):
        \(historyString)
        
        YOUR MISSION:
        1. Compare "Muscle Focus" vs "Goal".
        2. Analyze Consistency & Duration.
        3. Check for OVERLAP/RECOVERY issues.
        4. Provide 3 specific, actionable bullet points for next week (e.g. specific rep ranges, exercises to add/remove).
        
        Keep the advice short, punchy, and data-backed. Use Markdown.
        """
        
        return try await sendRequest(prompt: prompt)
    }
    
    // MARK: - 2. Routine Generator
    func generateRoutine(
        history: [WorkoutSession],
        existingRoutines: [Routine],
        availableExercises: [Exercise],
        profile: UserProfile?,
        focus: String,
        duration: Int,
        exerciseCount: Int,
        includeCardio: Bool,
        cardioDuration: Int,
        coachAdvice: String? = nil
    ) async throws -> (name: String, rawJSON: String, items: [AIRoutineItem]) {
        
        print("--- DEBUG: Starting Routine Generation ---")
        let exerciseList = availableExercises.map { $0.name }.joined(separator: ", ")
        
        var userContext = ""
        if let p = profile {
            userContext = """
            User Profile:
            - Goal: \(p.fitnessGoal)
            - Experience: \(p.experienceLevel)
            """
        }
        
        let adviceContext = (coachAdvice != nil && !coachAdvice!.isEmpty) ? "COACH'S STRATEGY: \(coachAdvice!)" : "COACH'S STRATEGY: None."
        
        var maxWeights: [String: Double] = [:]
        var cardioCounts: [String: Int] = [:]
        
        for session in history.prefix(30) {
            for set in session.sets {
                guard let name = set.exercise?.name else { continue }
                if set.weight > (maxWeights[name] ?? 0) { maxWeights[name] = set.weight }
                if set.distance != nil { cardioCounts[name, default: 0] += 1 }
            }
        }
        
        let performanceContext = maxWeights.map { "- \($0.key): Best \($0.value) lbs" }.joined(separator: "\n")
        let favoriteCardio = cardioCounts.sorted { $0.value > $1.value }.first?.key ?? "Treadmill"
        
        let prompt = """
        You are an expert strength coach. Create a custom workout routine menu.
        
        \(userContext)
        \(adviceContext)
        
        USER REQUEST: Focus: \(focus), Time: \(duration) min.
        CONSTRAINT: EXACTLY \(exerciseCount) exercises.
        CARDIO REQUEST: \(includeCardio ? "Yes, include a cardio finisher." : "No cardio.")
        CARDIO DURATION: \(cardioDuration) min (if applicable).
        
        My Available Exercises: [\(exerciseList)]
        
        My Stats:
        \(performanceContext)
        Favorite Cardio: \(favoriteCardio)
        
        INSTRUCTIONS:
        1. Select EXACTLY \(exerciseCount) exercises matching the focus.
        2. CRITICAL: Apply the 'COACH'S STRATEGY' to the Sets/Reps.
        3. Use my Strength Levels to suggest specific target weights.
        4. IF CARDIO IS REQUESTED:
           - The LAST exercise MUST be a cardio exercise.
           - Prioritize my "Favorite Cardio" (\(favoriteCardio)) if it fits the goal, otherwise suggest the best option.
           - Sets: 1
           - Reps: "\(cardioDuration) min"
           - Note: Suggest intensity (e.g. "Zone 2" or "HIIT intervals").
        5. Return RAW JSON ONLY.
        
        JSON Format:
        {
            "routineName": "Routine Name",
            "exercises": [
                { "name": "Exact Exercise Name", "sets": 3, "reps": "8-12", "note": "Target: 135lbs" }
            ]
        }
        """
        
        let responseText = try await sendRequest(prompt: prompt)
        return try parseRoutineJSON(responseText)
    }
    
    // MARK: - 3. Weekly Schedule Generator
    func generateWeeklySchedule(
        profile: UserProfile,
        history: [WorkoutSession],
        coachAdvice: String
    ) async throws -> WeeklyPlan {
        print("--- DEBUG: Starting Schedule Generation ---")
        
        var lastWorkoutContext = "No recent workouts."
        if let last = history.sorted(by: { $0.date > $1.date }).first {
            lastWorkoutContext = "Last workout was '\(last.name)' on \(last.date.formatted(date: .abbreviated, time: .omitted))."
        }
        
        let adviceContext = coachAdvice.isEmpty ? "No specific advice yet." : coachAdvice
        
        let prompt = """
        Act as a personal trainer. Create a 7-day workout schedule (Monday to Sunday) for this user.
        
        USER PROFILE:
        - Goal: \(profile.fitnessGoal)
        - Experience: \(profile.experienceLevel)
        - PREFERRED SPLIT: \(profile.splitPreference)
        
        CONTEXT:
        - \(lastWorkoutContext)
        
        COACH'S RECENT ADVICE:
        "\(adviceContext)"
        
        INSTRUCTIONS:
        1. Create a plan for the UPCOMING week (Mon-Sun).
        2. PRIORITIZE THE COACH'S ADVICE.
        3. Respect the user's Preferred Split, but adjust it to fit the Coach's advice.
        4. If they just did 'Legs', ensure Monday isn't Legs (recovery).
        5. For the 'focus' field, USE ONLY STANDARD SPLIT NAMES (e.g. 'Push', 'Pull', 'Legs', 'Upper Body', 'Lower Body', 'Full Body', 'Cardio', 'Rest').
        6. Return RAW JSON ONLY.
        
        JSON Format:
        {
            "weekFocus": "Brief 1-sentence focus for the week",
            "days": [
                { "day": "Monday", "focus": "Push", "description": "Chest, Shoulders, Triceps" },
                ... (for all 7 days)
            ]
        }
        """
        
        let responseText = try await sendRequest(prompt: prompt)
        return try parseScheduleJSON(responseText)
    }
    
    // MARK: - 4. Generate Routine Content (For Magic Wand / Auto-Schedule)
    
    struct AIGeneratedExercise: Decodable {
        let name: String
        let sets: Int
        let reps: Int
        let note: String?
    }
    
    func generateRoutineContent(name: String, profile: UserProfile?) async throws -> [AIGeneratedExercise] {
        let goal = profile?.fitnessGoal ?? "General Fitness"
        let level = profile?.experienceLevel ?? "Beginner"
        
        let prompt = """
        Act as an expert fitness coach. Create a workout session for a routine named: "\(name)".
        User Goal: \(goal)
        User Level: \(level)
        
        INSTRUCTIONS:
        1. List 4-7 appropriate exercises.
        2. Provide standard sets/reps (e.g. 3 sets of 10).
        3. Use standard exercise names (e.g. "Squat", "Bench Press").
        
        OUTPUT JSON ONLY:
        [
            { "name": "Exercise Name", "sets": 3, "reps": 10, "note": "Brief tip" }
        ]
        """
        
        let response = try await sendRequest(prompt: prompt)
        return try parseExerciseJSON(response)
    }
    
    private func parseExerciseJSON(_ text: String) throws -> [AIGeneratedExercise] {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]") else { return [] }
        
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8) else { return [] }
        
        return try JSONDecoder().decode([AIGeneratedExercise].self, from: data)
    }
    
    // MARK: - 5. File Importer (UPDATED: Captures Warmups & Notes)
    func parseRoutineFromText(_ text: String, validExercises: [Exercise]) async throws -> [AIImportedRoutine] {
        print("--- DEBUG: Starting File Import ---")
        
        let validNames = validExercises.map { $0.name }.joined(separator: ", ")
        
        let prompt = """
        You are a Data Structuring Specialist. Convert this unstructured workout text into valid JSON.
        
        INPUT TEXT:
        \"\(text.prefix(15000))\"
        
        MY VALID EXERCISE DATABASE:
        [\(validNames)]
        
        INSTRUCTIONS:
        1. Identify distinct Routines (e.g. "Day 1", "Push Day").
        2. Extract Exercises. INCLUDE WARM-UP SETS. Do not skip them.
        3. MAPPING RULE: Match exercises to my database exactly if possible.
        4. SUPERSETS / GIANT SETS:
           - If you see "Superset", "Giant Set", or "Cluster", identify which exercises belong to it.
           - Assign a UNIQUE 'supersetLabel' (e.g., "A", "B", "C") to the exercises in that group.
           - Leave 'supersetLabel' null/nil for standalone exercises.
        5. EXTRACT DETAILS:
           - Sets: Number of sets.
           - Reps: String (e.g. "10-12", "Failure", "40 sec").
           - Note: Capture ANY extra info here (e.g. "Drop set last set", "Warmup", "RPE 8", "Run the rack").
        
        JSON OUTPUT FORMAT:
        [
            {
                "routineName": "Day 1 - Chest",
                "exercises": [
                    {
                        "originalName": "Bench Press",
                        "mappedName": "Barbell Bench Press",
                        "confidence": "High",
                        "sets": 3,
                        "reps": "10",
                        "supersetLabel": null,
                        "note": "Last set drop set"
                    }
                ]
            }
        ]
        """
        
        let responseText = try await sendRequest(prompt: prompt)
        return try parseImportJSON(responseText)
    }
    
    // MARK: - 6. Smart Set Suggester (NEW: The "Magic Wand" Brain)
    func getSetSuggestion(
        exerciseName: String,
        history: [HistoryContext],
        goal: String
    ) async throws -> SetSuggestion {
        
        let historyList = history.prefix(5).map { item in
            "- \(item.date.formatted(date: .numeric, time: .omitted)): \(Int(item.weight)) lbs x \(item.reps)"
        }.joined(separator: "\n")
        
        let contextString = historyList.isEmpty ? "No previous history for this exercise." : historyList
        
        let prompt = """
        Act as an expert strength coach. Suggest the Weight and Reps for the NEXT set of: "\(exerciseName)".
        
        USER GOAL: \(goal)
        
        RECENT HISTORY (Oldest to Newest):
        \(contextString)
        
        INSTRUCTIONS:
        1. Apply Progressive Overload. If they hit their reps last time, increase weight slightly (2.5-5 lbs).
        2. If they struggled (low reps), keep weight same or lower.
        3. If history is empty, suggest a conservative starting point for a beginner.
        4. "reasoning" should be very short (max 10 words).
        
        OUTPUT JSON ONLY:
        { "weight": 135.0, "reps": 10, "reasoning": "Increased weight by 5lbs due to good volume." }
        """
        
        let response = try await sendRequest(prompt: prompt)
        return try parseSuggestionJSON(response)
    }
    
    private func parseSuggestionJSON(_ text: String) throws -> SetSuggestion {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return SetSuggestion(weight: 0, reps: 0, reasoning: "Error") }
        
        let jsonStr = String(text[start...end])
        guard let data = jsonStr.data(using: .utf8) else { return SetSuggestion(weight: 0, reps: 0, reasoning: "Error") }
        
        return try JSONDecoder().decode(SetSuggestion.self, from: data)
    }
    
    // MARK: - Internal Helpers
    
    private struct AnalysisStats {
        let workoutsPerWeek: String
        let avgDuration: String
        let muscleSplit: String
        let totalVolume: String
    }
    
    private func calculateStats(from sessions: [WorkoutSession]) -> AnalysisStats {
        let oneMonthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let recentSessions = sessions.filter { $0.date > oneMonthAgo }
        
        let freq = String(format: "%.1f", Double(recentSessions.count) / 4.0)
        
        let totalSeconds = recentSessions.reduce(0) { $0 + $1.duration }
        let avgSeconds = recentSessions.isEmpty ? 0 : totalSeconds / Double(recentSessions.count)
        let avgDur = "\(Int(avgSeconds / 60)) min"
        
        var vol: Double = 0
        var muscleCounts: [String: Int] = [:]
        
        for session in recentSessions {
            for set in session.sets {
                let w = set.unit == "kg" ? set.weight * 2.2 : set.weight
                vol += (w * Double(set.reps))
                
                if let muscle = set.exercise?.muscleGroup {
                    muscleCounts[muscle, default: 0] += 1
                }
            }
        }
        
        let sortedMuscles = muscleCounts.sorted { $0.value > $1.value }.prefix(3)
        let splitString = sortedMuscles.map { "\($0.key) (\($0.value) sets)" }.joined(separator: ", ")
        
        return AnalysisStats(
            workoutsPerWeek: freq,
            avgDuration: avgDur,
            muscleSplit: splitString.isEmpty ? "General Full Body" : splitString,
            totalVolume: "\(Int(vol))"
        )
    }
    
    private func parseRoutineJSON(_ text: String) throws -> (String, String, [AIRoutineItem]) {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            throw URLError(.cannotParseResponse)
        }
        let jsonString = String(text[start...end])
        
        guard let data = jsonString.data(using: .utf8),
              let responseObj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = responseObj["routineName"] as? String,
              let exercises = responseObj["exercises"] as? [[String: Any]]
        else { throw URLError(.cannotParseResponse) }
        
        let mappedItems = exercises.compactMap { dict -> AIRoutineItem? in
            guard let exName = dict["name"] as? String else { return nil }
            let sets = dict["sets"] as? Int ?? 3
            let repsVal = dict["reps"]
            let repsString = "\(repsVal ?? "10")"
            let note = dict["note"] as? String ?? ""
            return AIRoutineItem(name: exName, sets: sets, reps: repsString, note: note)
        }
        
        return (name, jsonString, mappedItems)
    }
    
    private func parseScheduleJSON(_ text: String) throws -> WeeklyPlan {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            throw URLError(.cannotParseResponse)
        }
        let jsonString = String(text[start...end])
        let data = jsonString.data(using: .utf8)!
        return try JSONDecoder().decode(WeeklyPlan.self, from: data)
    }
    
    private func parseImportJSON(_ text: String) throws -> [AIImportedRoutine] {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]") else {
            print("❌ Could not find JSON array brackets.")
            throw URLError(.cannotParseResponse)
        }
        
        let jsonString = String(text[start...end])
        print("🔍 RAW AI JSON: \(jsonString)")
        
        guard let data = jsonString.data(using: .utf8) else { throw URLError(.cannotParseResponse) }
        
        return try JSONDecoder().decode([AIImportedRoutine].self, from: data)
    }
}

// MARK: - Shared Structs

struct AIRoutineItem: Codable {
    let name: String
    let sets: Int
    let reps: String
    let note: String
}

struct WeeklyPlan: Codable {
    let weekFocus: String
    let days: [DaySchedule]
}

struct DaySchedule: Codable, Identifiable {
    var id: String { day }
    let day: String
    let focus: String
    let description: String
}

// MARK: - Import Models

struct AIImportedRoutine: Codable, Identifiable {
    var id: UUID = UUID()
    let routineName: String
    let exercises: [AIImportedExercise]
    
    enum CodingKeys: String, CodingKey {
        case routineName
        case exercises
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.routineName = try container.decodeIfPresent(String.self, forKey: .routineName) ?? "New Routine"
        self.exercises = try container.decodeIfPresent([AIImportedExercise].self, forKey: .exercises) ?? []
    }
}

struct AIImportedExercise: Codable, Identifiable {
    var id: UUID = UUID()
    let originalName: String
    let mappedName: String
    let confidence: String
    let sets: Int
    let reps: String
    let note: String?
    
    let supersetLabel: String?
    
    var isNewExercise: Bool { confidence == "None" }
    
    enum CodingKeys: String, CodingKey {
        case originalName, mappedName, confidence, sets, reps, note, supersetLabel
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.originalName = try container.decodeIfPresent(String.self, forKey: .originalName) ?? "Unknown Exercise"
        self.mappedName = try container.decodeIfPresent(String.self, forKey: .mappedName) ?? "Unknown Exercise"
        self.confidence = try container.decodeIfPresent(String.self, forKey: .confidence) ?? "None"
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        self.supersetLabel = try container.decodeIfPresent(String.self, forKey: .supersetLabel)
        
        if let setsInt = try? container.decode(Int.self, forKey: .sets) {
            self.sets = setsInt
        } else if let setsString = try? container.decode(String.self, forKey: .sets), let val = Int(setsString) {
            self.sets = val
        } else { self.sets = 3 }
        
        if let repsString = try? container.decode(String.self, forKey: .reps) {
            self.reps = repsString
        } else if let repsInt = try? container.decode(Int.self, forKey: .reps) {
            self.reps = String(repsInt)
        } else { self.reps = "10" }
    }
}
