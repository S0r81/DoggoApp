//
//  ProfileSettingsView.swift
//  Doggo
//
//  Created by Sorest on 1/14/26.
//

import SwiftUI
import SwiftData

struct ProfileSettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // We bind directly to the SwiftData model so changes save automatically
    @Bindable var profile: UserProfile
    
    // Local state for UI inputs (Imperial helpers)
    @State private var weightLbs: Int = 150
    @State private var heightInches: Int = 70
    
    let goals = ["Build Muscle", "Lose Fat", "Strength", "Endurance", "General Health"]
    let levels = ["Beginner", "Intermediate", "Advanced"]
    let activities = ["Sedentary", "Lightly Active", "Active", "Very Active (Athlete)"]
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Avatar / Header
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.blue)
                            Text(profile.name)
                                .font(.title2).bold()
                            Text(profile.experienceLevel)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                
                // MARK: - The AI Context (Editable)
                Section(header: Text("AI Coach Context"), footer: Text("The AI adjusts your routine volume and intensity based on these settings.")) {
                    
                    Picker("Current Goal", selection: $profile.fitnessGoal) {
                        ForEach(goals, id: \.self) { Text($0) }
                    }
                    
                    Picker("Activity Level", selection: $profile.activityLevel) {
                        ForEach(activities, id: \.self) { Text($0) }
                    }
                    
                    Picker("Experience", selection: $profile.experienceLevel) {
                        ForEach(levels, id: \.self) { Text($0) }
                    }
                }
                
                // MARK: - Physical Stats
                Section("Physical Stats") {
                    Stepper("Age: \(profile.age)", value: $profile.age, in: 12...100)
                    
                    // Weight Input (Converts Lbs -> KG)
                    HStack {
                        Text("Weight (lbs)")
                        Spacer()
                        TextField("Lbs", value: $weightLbs, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: weightLbs) { _, newValue in
                                profile.weightKG = Double(newValue) * 0.453592
                            }
                    }
                    
                    // Height Input (Converts In -> CM)
                    HStack {
                        Text("Height (in)")
                        Spacer()
                        TextField("Inches", value: $heightInches, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: heightInches) { _, newValue in
                                profile.heightCM = Double(newValue) * 2.54
                            }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
            .onAppear {
                // Initialize local state from the DB values
                weightLbs = Int(profile.weightKG * 2.20462)
                heightInches = Int(profile.heightCM / 2.54)
            }
        }
    }
}
