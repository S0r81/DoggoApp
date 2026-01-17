import SwiftUI
import SwiftData

struct WeeklyPlannerView: View {
    @Environment(\.dismiss) var dismiss
    
    @Query var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.date, order: .reverse) var history: [WorkoutSession]
    
    @AppStorage("cachedWeeklyPlanJSON") private var cachedJSON: String = ""
    @AppStorage("cachedCoachAdvice") private var cachedAdvice: String = ""
    
    @State private var currentPlan: WeeklyPlan?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var splitToGenerate: String?
    @State private var showGenerator = false
    
    private let manager = GeminiManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    if isLoading {
                        loadingView
                    } else if let plan = currentPlan {
                        
                        // Header
                        VStack(spacing: 8) {
                            Text("This Week's Focus")
                                .font(.caption).fontWeight(.bold).foregroundStyle(.secondary).textCase(.uppercase)
                            Text(plan.weekFocus)
                                .font(.title3).bold().multilineTextAlignment(.center).foregroundStyle(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // UI: Show "Adapted" ONLY if feature is ON
                        if let profile = profiles.first, profile.useCoachForSchedule, !cachedAdvice.isEmpty {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Adapted from Coach's Strategy")
                            }
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                        
                        // Days
                        VStack(spacing: 12) {
                            ForEach(plan.days) { day in
                                Button {
                                    handleDayTap(day)
                                } label: {
                                    DayScheduleCard(day: day)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        
                        Button(action: { generateSchedule() }) {
                            Label("Regenerate Schedule", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding()
                        
                    } else {
                        ContentUnavailableView("No Schedule Set", systemImage: "calendar.badge.clock", description: Text("Generate a smart 7-day plan based on your preferred split and recent history."))
                            .padding(.top, 40)
                        Button("Build My Week", action: { generateSchedule() })
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Weekly Planner")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .onAppear { loadCachedPlan() }
            .sheet(isPresented: $showGenerator) {
                if let focus = splitToGenerate {
                    RoutineGeneratorView(initialSplit: focus)
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("Building Schedule...")
                .foregroundStyle(.secondary)
            if let profile = profiles.first, profile.useCoachForSchedule {
                Text("Aligning with Coach's advice...")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(height: 300)
    }
    
    func handleDayTap(_ day: DaySchedule) {
        if day.focus.lowercased().contains("rest") { return }
        self.splitToGenerate = day.focus
        self.showGenerator = true
    }
    
    func generateSchedule() {
        guard let profile = profiles.first else { return }
        withAnimation { isLoading = true }
        
        Task {
            do {
                // LOGIC: Check toggle before sending advice
                let adviceToSend = profile.useCoachForSchedule ? cachedAdvice : ""
                
                let plan = try await manager.generateWeeklySchedule(
                    profile: profile,
                    history: history,
                    coachAdvice: adviceToSend
                )
                
                await MainActor.run {
                    self.currentPlan = plan
                    self.isLoading = false
                    if let data = try? JSONEncoder().encode(plan), let str = String(data: data, encoding: .utf8) {
                        self.cachedJSON = str
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func loadCachedPlan() {
        if !cachedJSON.isEmpty, let data = cachedJSON.data(using: .utf8) {
            if let decoded = try? JSONDecoder().decode(WeeklyPlan.self, from: data) {
                self.currentPlan = decoded
            }
        }
    }
}

// (Keep DayScheduleCard unchanged)
struct DayScheduleCard: View {
    let day: DaySchedule
    var isRestDay: Bool { day.focus.lowercased().contains("rest") }
    var body: some View {
        HStack(spacing: 16) {
            Text(day.day.prefix(3).uppercased())
                .font(.caption).bold().foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(isRestDay ? Color.gray.opacity(0.5) : Color.blue)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(day.focus).font(.headline).foregroundStyle(isRestDay ? .secondary : .primary)
            }
            Spacer()
            if isRestDay { Image(systemName: "moon.zzz.fill").foregroundStyle(.gray) }
            else { Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption) }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .opacity(isRestDay ? 0.8 : 1.0)
    }
}
