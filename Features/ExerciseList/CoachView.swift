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
    
    // NEW: Copy Confirmation State
    @State private var isCopied = false
    
    // Use the manager we just upgraded
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
                                ContentUnavailableView("Ready to Coach", systemImage: "dumbbell.fill", description: Text("I will analyze your volume, consistency, and muscle split to give you specific advice."))
                                    .padding()
                            } else {
                                // Display the advice with Markdown parsing support
                                Text(LocalizedStringKey(cachedAdvice))
                                    .padding()
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .cornerRadius(12)
                                    // Context Menu for Long Press Copy
                                    .contextMenu {
                                        Button {
                                            copyToClipboard()
                                        } label: {
                                            Label("Copy Report", systemImage: "doc.on.doc")
                                        }
                                    }
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
                        Image(systemName: "sparkles")
                    }
                    .disabled(isLoading)
                }
                
                // RIGHT SIDE: Copy & Done
                ToolbarItemGroup(placement: .confirmationAction) {
                    // COPY BUTTON
                    if !cachedAdvice.isEmpty {
                        Button(action: copyToClipboard) {
                            // Swap icon to checkmark briefly when copied
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .disabled(isLoading)
                    }
                    
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if cachedAdvice.isEmpty {
                generateReport(force: false)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Text("Calculating volume & consistency...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Analyzing muscle split...")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(height: 300)
    }
    
    private func generateReport(force: Bool) {
        withAnimation {
            isLoading = true
            errorMessage = nil
            isCopied = false
        }
        
        Task {
            do {
                let result = try await manager.generateAnalysis(
                    from: sessions,
                    profile: profiles.first
                )
                
                if result.contains("Rate Limit") && !cachedAdvice.isEmpty {
                    await MainActor.run { self.isLoading = false }
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
    
    // MARK: - Copy Helper
    private func copyToClipboard() {
        UIPasteboard.general.string = cachedAdvice
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Visual Feedback
        withAnimation { isCopied = true }
        
        // Reset icon after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { isCopied = false }
        }
    }
}
