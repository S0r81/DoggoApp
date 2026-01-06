//
//  ContentView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // Read the setting from storage
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            DashboardView()
                .applyTheme(userTheme) // <--- Apply the background here
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            
            RoutineListView(selectedTab: $selectedTab)
                .applyTheme(userTheme) // <--- And here
                .tabItem { Label("Lift", systemImage: "dumbbell") }
                .tag(1)
            
            ActiveWorkoutView()
                .applyTheme(userTheme) // <--- And here
                .tabItem { Label("Workout", systemImage: "waveform.path.ecg") }
                .tag(2)
        }
    }
}
