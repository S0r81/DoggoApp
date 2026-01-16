import Foundation

class GeminiManager {
    // YOUR WORKING KEY
    private let apiKey = ""
    
    // Gemini 2.0 Flash
    // Updated to use the high-limit "Lite" model (4,000 RPM)
    // Switch to the Advanced "Pro" model for smarter reasoning
        private let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"
    
    // MARK: - 1. Coach's Report (Updated with Profile)
    func generateAnalysis(from sessions: [WorkoutSession], profile: UserProfile?) async throws -> String {
        print("--- DEBUG: Starting AI Request (Gemini 2.0) ---")
        
        // --- STEP 1: PREPARE DATA ---
        let recentHistory = sessions.prefix(15)
        var contextString = "Here is my recent workout history:\n"
        
        if recentHistory.isEmpty {
            return "No workout history found. Log a workout to get coaching advice!"
        }
        
        for session in recentHistory {
            let date = session.date.formatted(date: .numeric, time: .omitted)
            contextString += "- Date: \(date), Routine: \(session.name), Duration: \(Int(session.duration/60)) mins\n"
            
            for set in session.sets {
                if let exercise = set.exercise {
                    if exercise.type == "Cardio" {
                        contextString += "  * \(exercise.name): \(set.distance ?? 0) \(set.unit) in \(set.duration ?? 0) mins\n"
                    } else {
                        contextString += "  * \(exercise.name): \(Int(set.weight)) \(set.unit) x \(set.reps) reps\n"
                    }
                }
            }
        }
        
        // --- STEP 2: PREPARE USER CONTEXT ---
        var userContext = ""
        if let p = profile {
            userContext = p.aiDescription + "\n\n"
        }
        
        // --- STEP 3: THE PROMPT ---
        let prompt = """
        You are an elite strength and conditioning coach. Analyze the following workout history for a user.
        
        \(userContext)
        
        Your Goal:
        1. Identify the user's focus (e.g., "Mainly pushing", "Skipping legs").
        2. Spot any plateaus or consistency issues based on their Goal and Level.
        3. Provide 3 specific, actionable bullet points to improve their progress next week.
        
        Keep the tone encouraging but direct. Use Markdown formatting.
        
        \(contextString)
        """
        
        // --- STEP 4: BUILD REQUEST ---
        guard let url = URL(string: urlString) else { return "Invalid URL" }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Headers
        request.addValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        // --- STEP 5: SEND ---
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                return "⚠️ The Coach is busy right now (Rate Limit Reached). Please wait 1 minute and try again."
            }
            if httpResponse.statusCode != 200 {
                return "Error: Server returned \(httpResponse.statusCode). Please try again later."
            }
        }
        
        // --- STEP 6: DECODE ---
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return text
            }
        }
        
        return "Failed to parse Coach's advice."
    }
    
    // MARK: - 2. Routine Generator (Updated with Profile)
    func generateRoutine(
        history: [WorkoutSession],
        existingRoutines: [Routine],
        availableExercises: [Exercise],
        profile: UserProfile?,  // <--- NEW PARAMETER
        focus: String,
        duration: Int
    ) async throws -> (name: String, rawJSON: String, items: [AIRoutineItem]) {
        
        print("--- DEBUG: Starting Smart Routine Generation ---")
        let exerciseList = availableExercises.map { $0.name }.joined(separator: ", ")
        
        // 1. Performance Context
        var performanceContext = ""
        let recentSessions = history.prefix(20)
        var maxWeights: [String: Double] = [:]
        for session in recentSessions {
            for set in session.sets {
                guard let name = set.exercise?.name else { continue }
                if set.weight > (maxWeights[name] ?? 0) { maxWeights[name] = set.weight }
            }
        }
        for (name, weight) in maxWeights {
            performanceContext += "- \(name): Best recent set was \(Int(weight)) lbs\n"
        }
        
        // 2. User Context
        var userContext = ""
        if let p = profile {
            userContext = p.aiDescription + "\n\n"
        }
        
        // 3. The Prompt
        let prompt = """
        You are an expert strength coach. Create a custom workout routine menu.
        
        \(userContext)
        
        USER REQUEST: Focus: \(focus), Time: \(duration) min.
        
        My Available Exercises: [\(exerciseList)]
        My Strength Levels: \(performanceContext)
        
        INSTRUCTIONS:
        1. Select exercises matching the focus and my Experience Level/Goal.
        2. Assign Sets and Reps specific to my Goal (e.g. Lower reps for Strength, Higher for Endurance).
        3. Calculate a target weight or note.
        4. Return RAW JSON ONLY.
        
        JSON Format:
        {
            "routineName": "Routine Name",
            "exercises": [
                { "name": "Exact Exercise Name", "sets": 3, "reps": "8-12", "note": "Target: 135lbs" }
            ]
        }
        """
        
        // Networking
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        // Decoding
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           var text = parts.first?["text"] as? String {
            
            // Clean Markdown
            text = text.replacingOccurrences(of: "```json", with: "")
            text = text.replacingOccurrences(of: "```", with: "")
            let rawJSON = text // Save this for History
            
            guard let data = text.data(using: .utf8),
                  let responseObj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = responseObj["routineName"] as? String,
                  let exercises = responseObj["exercises"] as? [[String: Any]]
            else { throw URLError(.cannotParseResponse) }
            
            // Map to Struct
            let mappedItems = exercises.compactMap { dict -> AIRoutineItem? in
                guard let exName = dict["name"] as? String else { return nil }
                let sets = dict["sets"] as? Int ?? 3
                let repsVal = dict["reps"]
                let repsString = "\(repsVal ?? "10")"
                let note = dict["note"] as? String ?? ""
                
                return AIRoutineItem(name: exName, sets: sets, reps: repsString, note: note)
            }
            
            return (name, rawJSON, mappedItems)
        }
        
        throw URLError(.cannotParseResponse)
    }
}

// Helper Struct
struct AIRoutineItem: Codable {
    let name: String
    let sets: Int
    let reps: String
    let note: String
}
