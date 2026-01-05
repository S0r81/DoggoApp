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
        }
    }
    
    // Allow deleting history items
    @Environment(\.modelContext) private var modelContext
    private func deleteSession(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
    }
}
