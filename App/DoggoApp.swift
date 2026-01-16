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
    // 1. THEME STORAGE
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    
    // 2. CONTAINER SETUP
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self,
            Routine.self,
            RoutineItem.self,
            RoutineSetTemplate.self,
            // NEW MODELS ADDED HERE:
            AIGeneratedRoutine.self,
            UserProfile.self
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
            // We switch to RootView to handle the logic
            RootView()
                .preferredColorScheme(userTheme == .light ? .light : .dark)
                .tint(Color.accent(for: userTheme))
                .onAppear {
                    // Seed Data logic runs once on launch
                    let context = sharedModelContainer.mainContext
                    DataSeeder.seedExercises(context: context)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// 3. NEW ROOT VIEW (Handles the Traffic Control)
struct RootView: View {
    @Environment(\.modelContext) var modelContext
    // Fetch profiles to check if one exists
    @Query var profiles: [UserProfile]
    
    @State private var isOnboarding = false
    
    var body: some View {
        Group {
            if isOnboarding {
                // If no profile, show Onboarding
                OnboardingView(isOnboardingComplete: $isOnboarding)
            } else {
                // Otherwise, show the main app
                ContentView()
            }
        }
        .onAppear {
            // Immediate check on launch
            if profiles.isEmpty {
                isOnboarding = true
            }
        }
        // Watch for changes (e.g., if you delete your profile in Settings)
        .onChange(of: profiles.isEmpty) { oldValue, newValue in
            if newValue {
                isOnboarding = true
            }
        }
    }
}
