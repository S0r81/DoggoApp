//
//  DoggoApp.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

@main
struct DoggoApp: App {
    // 1. THEME STORAGE: This saves the user's choice
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    
    // 2. CONTAINER SETUP (Your existing code)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self,
            Routine.self,
            RoutineItem.self,
            RoutineSetTemplate.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 3. APPLY THEME: Inject the colors here
                .preferredColorScheme(userTheme == .light ? .light : .dark)
                .tint(Color.accent(for: userTheme))
                // 4. NEW: SEED DATA
                // This runs once on app launch. If the DB is empty, it loads the defaults.
                .onAppear {
                    let context = sharedModelContainer.mainContext
                    DataSeeder.seedExercises(context: context)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
