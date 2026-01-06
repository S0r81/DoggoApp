//
//  DashboardView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData
import Charts // <--- NEW: Required for the Bar Chart

struct DashboardView: View {
    // 1. Initialize the ViewModel
    @State private var viewModel = DashboardViewModel()
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @State private var showSettings = false
    
    // 2. Fetch data
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
                            Text(viewModel.greetingMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Let's get to work.")
                                .font(.title)
                                .bold()
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // NEW: Weekly Activity Chart
                    // This gives a quick visual of consistency
                    VStack(alignment: .leading, spacing: 10) {
                        Text("This Week")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            // Uses the ViewModel logic to get daily counts
                            ForEach(viewModel.getWeeklyActivity(from: recentSessions)) { day in
                                BarMark(
                                    x: .value("Day", day.day),
                                    y: .value("Workouts", day.count)
                                )
                                // Active days are Blue, Empty days are faint Gray
                                .foregroundStyle(day.count > 0 ? Color.blue : Color.gray.opacity(0.3))
                                .cornerRadius(4)
                            }
                        }
                        .frame(height: 150)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Stats Grid
                    HStack(spacing: 16) {
                        // Card 1: Total Workouts
                        StatCard(
                            title: "Total Workouts",
                            value: "\(recentSessions.count)",
                            icon: "dumbbell.fill",
                            color: .blue
                        )
                        
                        // Card 2: Total Volume (Dynamic Unit Support!)
                        // This calculates total weight lifted, normalized to your lbs/kg setting
                        StatCard(
                            title: "Total Volume",
                            value: viewModel.getTotalVolume(from: recentSessions, preferredUnit: unitSystem.rawValue),
                            icon: "chart.bar.fill",
                            color: .green
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
                AppSettingsView()
                    .presentationDetents([.medium])
            }
            .navigationTitle("Dashboard")
        }
    }
}

// MARK: - Subviews (Unchanged)

struct AppSettingsView: View {
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $userTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Units") {
                    Picker("System", selection: $unitSystem) {
                        Text("Imperial (lbs/mi)").tag(UnitSystem.imperial)
                        Text("Metric (kg/km)").tag(UnitSystem.metric)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Text("Doggo App v1.0")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

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
                    .minimumScaleFactor(0.8) // Helps if the volume number gets huge
                    .lineLimit(1)
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
