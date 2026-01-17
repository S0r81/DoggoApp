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
    @State private var showPlanner = false
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    
    // Sheets
    @State private var showSettings = false
    @State private var showProfile = false
    
    // Tab States for Paging
    @State private var consistencyPage: Int = 4 // Default to last (current week)
    @State private var volumePage: Int = 2      // Default to last (current month)
    
    // Fetch History
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    ) var recentSessions: [WorkoutSession]
    
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
                    
                    // SWIPABLE CHARTS
                    weeklyConsistencyView
                    volumeTrendView
                    
                    recentBestsView
                    workoutFocusView
                    lastWorkoutView
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            
            // Sheets
            .sheet(isPresented: $showSettings) {
                AppSettingsView().presentationDetents([.medium])
            }
            .sheet(isPresented: $showCoach) {
                CoachView(sessions: recentSessions)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showProfile) {
                if let user = profiles.first {
                    ProfileSettingsView(profile: user)
                } else {
                    ContentUnavailableView("Profile Error", systemImage: "exclamationmark.triangle")
                }
            }
            // NEW: Planner Sheet
            .sheet(isPresented: $showPlanner) {
                WeeklyPlannerView()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            
            Button(action: { showProfile = true }) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
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
                    
                    Button(action: { showCoach = true }) {
                        QuickActionButton(title: "AI Coach", icon: "brain.head.profile", color: .orange)
                    }
                    
                    // NEW: Planner Button
                    Button(action: { showPlanner = true }) {
                        QuickActionButton(title: "Plan Week", icon: "calendar.badge.clock", color: .teal)
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
    
    // MARK: - PAGED Consistency Chart (No Dots)
    private var weeklyConsistencyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Consistency").font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            let pages = viewModel.getConsistencyPages(from: recentSessions)
            
            if pages.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar")
            } else {
                TabView(selection: $consistencyPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(alignment: .leading) {
                            Text(page.label)
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 8)
                            
                            Chart {
                                ForEach(page.days) { day in
                                    BarMark(
                                        x: .value("Day", day.day),
                                        y: .value("Workouts", day.count)
                                    )
                                    .foregroundStyle(LinearGradient(colors: day.count > 0 ? [.blue, .purple] : [.gray.opacity(0.2)], startPoint: .bottom, endPoint: .top))
                                    .cornerRadius(6)
                                }
                            }
                            .chartYAxis(.hidden)
                        }
                        .padding()
                        .tag(index) // Important for selection
                    }
                }
                // FIXED: Hides the "Pill/Dots" indicator
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 160) // Reduced height since we removed the dots area
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - PAGED Volume Chart (No Dots)
    private var volumeTrendView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.green)
                Text("Volume Trend")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            let pages = viewModel.getVolumePages(from: recentSessions)
            
            if pages.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar")
                    .frame(height: 150)
            } else {
                TabView(selection: $volumePage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(alignment: .leading) {
                            Text(page.label)
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 8)
                            
                            Chart {
                                ForEach(page.weeks) { item in
                                    LineMark(
                                        x: .value("Week", item.weekLabel),
                                        y: .value("Volume", item.volume)
                                    )
                                    .interpolationMethod(.catmullRom) // Smooth curves
                                    .symbol(Circle())
                                    .foregroundStyle(Color.green)
                                    
                                    AreaMark(
                                        x: .value("Week", item.weekLabel),
                                        y: .value("Volume", item.volume)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green.opacity(0.3), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel {
                                        if let vol = value.as(Double.self) {
                                            Text("\(Int(vol / 1000))k")
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .tag(index)
                    }
                }
                // FIXED: Hides the "Pill/Dots" indicator
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 200)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
            }
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
                            if let exercise = best.exercise {
                                NavigationLink(destination: ExerciseAnalyticsView(exercise: exercise)) {
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
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var workoutFocusView: some View {
        WorkoutFocusCard(data: viewModel.getTopExercises(from: recentSessions))
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

// MARK: - Interactive Workout Focus Card
struct WorkoutFocusCard: View {
    let data: [ExerciseStat]
    @State private var selectedSegment: String? = nil
    private let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
    
    private var totalSets: Int {
        data.reduce(0) { $0 + $1.count }
    }
    
    private func color(for exerciseName: String) -> Color {
        if let index = data.firstIndex(where: { $0.name == exerciseName }) {
            return colors[index % colors.count]
        }
        return .gray
    }
    
    private var selectedStat: ExerciseStat? {
        guard let name = selectedSegment else { return nil }
        return data.first { $0.name == name }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Focus").font(.headline).padding(.horizontal)
            
            VStack(spacing: 8) {
                if let stat = selectedStat {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(color(for: stat.name))
                            .frame(width: 10, height: 10)
                        Text(stat.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("Tap a segment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.65),
                        angularInset: 2
                    )
                    .cornerRadius(5)
                    .foregroundStyle(by: .value("Name", item.name))
                    .opacity(selectedSegment == nil || selectedSegment == item.name ? 1.0 : 0.4)
                }
                .chartLegend(.hidden)
                .chartBackground { proxy in
                    VStack(spacing: 2) {
                        if let stat = selectedStat {
                            Text("\(stat.count)")
                                .font(.title)
                                .bold()
                                .foregroundStyle(color(for: stat.name))
                            Text("sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(totalSets)")
                                .font(.title)
                                .bold()
                                .foregroundStyle(.primary)
                            Text("Total Sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 180, height: 180)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                handleTap(at: location, in: geometry.size)
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.2), value: selectedSegment)
        }
    }
    
    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let outerRadius = min(size.width, size.height) / 2
        let innerRadius = outerRadius * 0.65
        
        guard distance >= innerRadius && distance <= outerRadius else {
            withAnimation {
                selectedSegment = nil
            }
            return
        }
        
        var angle = atan2(dx, -dy)
        if angle < 0 {
            angle += 2 * .pi
        }
        let tapPercentage = angle / (2 * .pi)
        
        var cumulativePercentage: Double = 0
        let total = Double(totalSets)
        
        for item in data {
            let segmentPercentage = Double(item.count) / total
            if tapPercentage >= cumulativePercentage && tapPercentage < cumulativePercentage + segmentPercentage {
                withAnimation {
                    if selectedSegment == item.name {
                        selectedSegment = nil
                    } else {
                        selectedSegment = item.name
                    }
                }
                return
            }
            cumulativePercentage += segmentPercentage
        }
    }
}

// MARK: - Components (Keeping existing ones)

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
                    Text("Doggo App v1.5")
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
