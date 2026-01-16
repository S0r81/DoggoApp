import SwiftUI
import SwiftData

struct CoachView: View {
    @Environment(\.dismiss) var dismiss
    let sessions: [WorkoutSession]
    
    // 1. Fetch the User Profile for context
    @Query var profiles: [UserProfile]
    
    // Persist the advice and the timestamp
    @AppStorage("cachedCoachAdvice") private var cachedAdvice: String = ""
    @AppStorage("cachedCoachTimestamp") private var cachedTimestamp: Double = 0
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let manager = GeminiManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        // Error State
                        ContentUnavailableView {
                            Label("Coach Unavailable", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Try Again") { generateReport(force: true) }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        // Success View (Shows Cached or New Data)
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Coach's Report")
                                    .font(.title2).bold()
                                Spacer()
                                if cachedTimestamp > 0 {
                                    Text("Generated: \(Date(timeIntervalSince1970: cachedTimestamp).formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if cachedAdvice.isEmpty {
                                Text("No analysis generated yet. Tap the star icon to start.")
                                    .foregroundStyle(.secondary)
                                    .padding()
                            } else {
                                Text(LocalizedStringKey(cachedAdvice))
                                    .padding()
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // LEFT SIDE: The "New Report" Button
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { generateReport(force: true) }) {
                        Image(systemName: "sparkles") // The AI Star Icon
                    }
                    .disabled(isLoading)
                }
                
                // RIGHT SIDE: The "Done" Button
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            // Logic: Only auto-generate if we have absolutely nothing.
            // Otherwise, we wait for the user to tap the "Sparkles" button.
            if cachedAdvice.isEmpty {
                generateReport(force: false)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Text("Analyzing workout history...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(height: 300)
    }
    
    private func generateReport(force: Bool) {
        withAnimation {
            isLoading = true
            errorMessage = nil
        }
        
        Task {
            do {
                // UPDATE: Pass the profile (if it exists)
                let result = try await manager.generateAnalysis(
                    from: sessions,
                    profile: profiles.first
                )
                
                // If Rate Limit hit, don't overwrite the old good advice with an error message
                if result.contains("Rate Limit") && !cachedAdvice.isEmpty {
                    await MainActor.run {
                        // Just show a toast or alert in a real app,
                        // for now we just stop loading and keep old text
                        self.isLoading = false
                    }
                    return
                }
                
                await MainActor.run {
                    self.cachedAdvice = result
                    self.cachedTimestamp = Date().timeIntervalSince1970
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
