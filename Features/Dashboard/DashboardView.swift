//
//  DashboardView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    // 1. Initialize the ViewModel
    @State private var viewModel = DashboardViewModel()
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @State private var showSettings = false
    
    // 2. Fetch data (SwiftData handles the auto-updates here)
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    ) var recentSessions: [WorkoutSession]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text(viewModel.greetingMessage) // Logic from VM
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Let's get to work.")
                                .font(.title)
                                .bold()
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Stats Grid
                    HStack(spacing: 16) {
                        StatCard(
                            title: "This Week",
                            // Pass data to VM for calculation
                            value: "\(viewModel.getWorkoutsThisWeek(from: recentSessions))",
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "Total Workouts",
                            value: "\(recentSessions.count)", // Simple count doesn't need VM logic
                            icon: "dumbbell.fill",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    // Recent Activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if let lastWorkout = recentSessions.first {
                            NavigationLink(destination: WorkoutDetailView(session: lastWorkout)) {
                                RecentWorkoutRow(session: lastWorkout)
                            }
                        } else {
                            Text("No workouts yet. Go to the Workout tab to start!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
            }
            .toolbar {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
            .sheet(isPresented: $showSettings) {
                ThemeSettingsView(currentTheme: $userTheme)
                    .presentationDetents([.fraction(0.3)]) // Small sheet
            }
            .navigationTitle("Dashboard")
        }
    }
}

// Sub-view for the recent workout row (Keeps the main view clean)
struct RecentWorkoutRow: View {
    let session: WorkoutSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// Re-using the StatCard from before...
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Spacer()
                Text(value)
                    .font(.title)
                    .bold()
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
}

struct ThemeSettingsView: View {
    @Binding var currentTheme: AppTheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Picker("Theme", selection: $currentTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .pickerStyle(.inline) // Shows them as a list of options
            }
            .navigationTitle("Appearance")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}
