//
//  ContentView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // 1. Create a State to control the active tab
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // Tab 0: Dashboard
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Tab 1: Routines (FIXED LINE BELOW)
            // We must pass the binding here too!
            RoutineListView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Lift", systemImage: "dumbbell.fill")
                }
                .tag(1)
            
            // Tab 2: Active Workout
            ActiveWorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "waveform.path.ecg")
                }
                .tag(2)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, Routine.self, Exercise.self])
}
