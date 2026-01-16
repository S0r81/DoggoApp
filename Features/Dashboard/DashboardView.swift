//
//  DashboardView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Binding var selectedTab: Int
    @State private var showCoach = false
    @State private var viewModel = DashboardViewModel()
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    
    // Sheets
    @State private var showSettings = false // App Settings (Theme/Units)
    @State private var showProfile = false  // User Profile (Stats/Goals)
    
    // Fetch History
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    ) var recentSessions: [WorkoutSession]
    
    // NEW: Fetch Profile for Greeting & Edit
    @Query var profiles: [UserProfile]
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    // MARK: - Main Body
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerView
                    quickActionsView
                    statsGridView
                    weeklyConsistencyView
                    recentBestsView
                    workoutFocusView
                    lastWorkoutView
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            
            // 1. App Settings Sheet
            .sheet(isPresented: $showSettings) {
                AppSettingsView().presentationDetents([.medium])
            }
            // 2. AI Coach Sheet
            .sheet(isPresented: $showCoach) {
                CoachView(sessions: recentSessions)
                    .presentationDetents([.medium, .large])
            }
            // 3. NEW: Profile Settings Sheet
            .sheet(isPresented: $showProfile) {
                if let user = profiles.first {
                    ProfileSettingsView(profile: user)
                } else {
                    ContentUnavailableView("Profile Error", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Moved App Settings to Toolbar (Gear Icon)
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
    
    // MARK: - Sub-Views
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // NEW: Dynamic Greeting
                if let name = profiles.first?.name {
                    Text("\(viewModel.greetingMessage), \(name)".uppercased())
                        .font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                } else {
                    Text(viewModel.greetingMessage.uppercased())
                        .font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                }
                
                Text("Let's get to work.")
                    .font(.title).bold()
            }
            Spacer()
            
            // UPDATED: Tapping the Avatar opens Profile Settings
            Button(action: { showProfile = true }) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 40)) // Slightly larger
                    .foregroundStyle(Color.accentColor) // Active color
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var quickActionsView: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button(action: { selectedTab = 2 }) {
                        QuickActionButton(title: "Log Workout", icon: "plus", color: .blue)
                    }
                    
                    Button(action: { selectedTab = 1 }) {
                        QuickActionButton(title: "New Routine", icon: "list.bullet.clipboard", color: .purple)
                    }
                    
                    // Triggers the Coach
                    Button(action: { showCoach = true }) {
                        QuickActionButton(title: "AI Coach", icon: "brain.head.profile", color: .orange)
                    }
                }
                .padding(.horizontal)
            }
        }
    
    private var statsGridView: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            StatCard(title: "Workouts", value: "\(recentSessions.count)", icon: "dumbbell.fill", color: .blue)
            StatCard(title: "Volume", value: viewModel.getTotalVolume(from: recentSessions, preferredUnit: unitSystem.rawValue), icon: "chart.bar.fill", color: .green)
            StatCard(title: "Time", value: viewModel.getTotalDuration(from: recentSessions), icon: "clock.fill", color: .orange)
            StatCard(title: "Streak", value: "\(viewModel.getCurrentStreak(from: recentSessions)) Days", icon: "flame.fill", color: .red)
        }
        .padding(.horizontal)
    }
    
    private var weeklyConsistencyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consistency").font(.headline).padding(.horizontal)
            Chart {
                ForEach(viewModel.getWeeklyActivity(from: recentSessions)) { day in
                    BarMark(x: .value("Day", day.day), y: .value("Workouts", day.count))
                        .foregroundStyle(LinearGradient(colors: day.count > 0 ? [.blue, .purple] : [.gray.opacity(0.2)], startPoint: .bottom, endPoint: .top))
                        .cornerRadius(6)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 140)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var recentBestsView: some View {
        if !recentSessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Heavy Lifts").font(.headline).padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.getRecentBests(from: recentSessions)) { best in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                                    Text(best.exerciseName).font(.subheadline).bold().lineLimit(1)
                                }
                                Text("\(Int(best.weight)) \(best.unit)")
                                    .font(.title2).bold().monospacedDigit()
                                Text(best.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(width: 160)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var workoutFocusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Focus").font(.headline).padding(.horizontal)
            
            let data = viewModel.getTopExercises(from: recentSessions)
            let totalSets = data.reduce(0) { $0 + $1.count }
            
            // Defines a simple color cycle for the legend to loosely match the chart
            let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
            
            HStack(spacing: 20) {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.65),
                        angularInset: 2
                    )
                    .cornerRadius(5) // FIX 1: CornerRadius must be BEFORE foregroundStyle
                    .foregroundStyle(by: .value("Name", item.name))
                }
                .chartLegend(.hidden)
                .chartBackground { proxy in
                    VStack(spacing: 0) {
                        Text("\(totalSets)").font(.title2).bold().foregroundStyle(.primary)
                        Text("Sets").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 140, height: 140)
                
                // Legend
                VStack(alignment: .leading, spacing: 10) {
                    // We use Array(zip) to get index for color matching
                    ForEach(Array(data.prefix(4).enumerated()), id: \.offset) { index, item in
                        HStack {
                            Circle()
                                // FIX 2: Use a standard Color, not .value(...)
                                .foregroundStyle(colors[index % colors.count])
                                .frame(width: 8, height: 8)
                            Text(item.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
                            Spacer()
                            Text("\(item.count)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    private var lastWorkoutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last Session").font(.headline)
                Spacer()
                NavigationLink(destination: HistoryView()) {
                    Text("History >").font(.subheadline).foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            
            if let last = recentSessions.first {
                NavigationLink(destination: WorkoutDetailView(session: last)) {
                    LastWorkoutHero(session: last)
                }
            } else {
                ContentUnavailableView("Start your journey", systemImage: "figure.run")
            }
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Components

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title).fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .cornerRadius(20)
    }
}

struct LastWorkoutHero: View {
    let session: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(session.name)
                        .font(.title3).bold()
                        .foregroundStyle(.white)
                    Text(session.date.formatted(date: .complete, time: .shortened))
                        .font(.caption).foregroundStyle(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Duration").font(.caption).foregroundStyle(.gray)
                    Text("\(Int(session.duration / 60)) min").bold().foregroundStyle(.white)
                }
                
                VStack(alignment: .leading) {
                    Text("Exercises").font(.caption).foregroundStyle(.gray)
                    Text("\(getUniqueExerciseCount(session))").bold().foregroundStyle(.white)
                }
                
                VStack(alignment: .leading) {
                    Text("Sets").font(.caption).foregroundStyle(.gray)
                    Text("\(session.sets.count)").bold().foregroundStyle(.white)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color(uiColor: .secondarySystemBackground), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(20)
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    func getUniqueExerciseCount(_ session: WorkoutSession) -> Int {
        let unique = Set(session.sets.compactMap { $0.exercise?.id })
        return unique.count
    }
}

struct AppSettingsView: View {
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds: Int = 90
    
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    ) var allHistory: [WorkoutSession]
    
    @Environment(\.dismiss) var dismiss
    
    let restOptions = [30, 60, 90, 120, 180, 240, 300]
    
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
                
                Section("Timer") {
                    Picker("Default Rest Time", selection: $defaultRestSeconds) {
                        ForEach(restOptions, id: \.self) { seconds in
                            let min = seconds / 60
                            let sec = seconds % 60
                            if sec == 0 {
                                Text("\(min) min").tag(seconds)
                            } else {
                                Text("\(min)m \(sec)s").tag(seconds)
                            }
                        }
                    }
                }
                
                Section("Data Management") {
                    if let csvURL = DataExporter.createCSVFile(from: allHistory) {
                        ShareLink(item: csvURL) {
                            Label("Export History to CSV", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Text("Unable to generate export").foregroundStyle(.secondary)
                    }
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
                    .minimumScaleFactor(0.8)
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
