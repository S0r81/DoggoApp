//
//  HistoryView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    // Query only COMPLETED sessions, sorted with newest first
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    ) var sessions: [WorkoutSession]
    
    @Environment(\.modelContext) private var modelContext
    
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
                                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                // Small summary pill
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
            // NEW: Add Button to Log Past Workout
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createManualEntry) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    // NEW: Function to create a blank history entry
    private func createManualEntry() {
        let newSession = WorkoutSession(name: "Manual Log")
        newSession.startTime = Date()
        newSession.date = Date()
        newSession.isCompleted = true // Mark as history immediately
        newSession.duration = 3600 // Default 60 mins
        
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
