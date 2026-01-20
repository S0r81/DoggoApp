//
//  HistoryView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    // Query only COMPLETED sessions
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    ) var sessions: [WorkoutSession]
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var showImportSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock.arrow.circlepath")
                } else {
                    ForEach(sessions) { session in
                        NavigationLink(destination: WorkoutDetailView(session: session)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(session.name)
                                        .font(.headline)
                                    // Shows Date AND Time now
                                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(session.duration / 60)) min")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .onDelete(perform: deleteSession)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showImportSheet = true }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createManualEntry) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                HistoryImportView()
            }
            // MARK: - AUTO-FIX (Silent Cleanup)
            .task {
                await performSilentCleanup()
            }
        }
    }
    
    // Deletes "Ghost" sessions automatically
    private func performSilentCleanup() async {
        do {
            let descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate<WorkoutSession> { $0.isCompleted == false }
            )
            let activeSessions = try modelContext.fetch(descriptor)
            
            for session in activeSessions {
                // If a session is incomplete AND older than 24 hours, it's a bug/ghost. Kill it.
                // We use -86400 seconds (1 day) as the threshold.
                if session.date < Date().addingTimeInterval(-86400) {
                    modelContext.delete(session)
                    print("👻 Silently deleted ghost session from: \(session.date)")
                }
            }
        } catch {
            print("Cleanup error: \(error)")
        }
    }
    
    private func createManualEntry() {
        let newSession = WorkoutSession(name: "Manual Log")
        newSession.startTime = Date()
        newSession.date = Date()
        newSession.isCompleted = true
        newSession.duration = 3600
        modelContext.insert(newSession)
    }
    
    private func deleteSession(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sessions[index])
            }
        }
    }
}
