import SwiftUI

struct SetRowView: View {
    @Bindable var set: WorkoutSet
    var index: Int
    
    // Controls for the two pickers
    @State private var showWeightPicker = false
    @State private var showRepsPicker = false
    
    // CHANGE 1: Dynamic Range based on the set's CURRENT unit
    var weightOptions: [Double] {
        if set.unit == "kg" {
            // Metric: 0-300 in 1kg increments
            return Array(stride(from: 0, through: 300, by: 1.0))
        } else {
            // Imperial: 0-600 in 2.5lb increments
            return Array(stride(from: 0, through: 600, by: 2.5))
        }
    }
    
    let repsOptions: [Int] = Array(0...100)
    
    var body: some View {
        HStack {
            // 1. Set Number
            Text("\(index)")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            // 2. Weight + Unit Input
            // We wrap them in an HStack so they look like one box, but have separate interactions
            HStack(spacing: 0) {
                
                // A. The Number (Triggers Picker)
                Button(action: {
                    showWeightPicker = true
                }) {
                    Text("\(set.weight, format: .number)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity) // Take up remaining space
                }
                .sheet(isPresented: $showWeightPicker) {
                    VStack {
                        Text("Select Weight (\(set.unit))")
                            .font(.headline)
                            .padding(.top)
                        
                        Picker("Weight", selection: $set.weight) {
                            ForEach(weightOptions, id: \.self) { weight in
                                // Show the unit in the picker too
                                Text("\(weight, format: .number)").tag(weight)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                    }
                    .presentationDetents([.fraction(0.3)])
                    .presentationDragIndicator(.visible)
                }
                
                // B. The Unit (Triggers Menu to swap lbs/kg)
                Menu {
                    Button("lbs") { set.unit = "lbs" }
                    Button("kg") { set.unit = "kg" }
                } label: {
                    Text(set.unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8) // Touch target size
                        .background(Color.secondary.opacity(0.1)) // Subtle background for the menu button
                        .cornerRadius(4)
                }
                .padding(.trailing, 8)
            }
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .frame(maxWidth: .infinity) // Ensure the whole container stretches
            
            // 3. Reps Input (Triggers Reps Sheet)
            Button(action: {
                showRepsPicker = true
            }) {
                VStack(spacing: 2) {
                    Text("\(set.reps)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    
                    Text("reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showRepsPicker) {
                VStack {
                    Text("Select Reps")
                        .font(.headline)
                        .padding(.top)
                    
                    Picker("Reps", selection: $set.reps) {
                        ForEach(repsOptions, id: \.self) { rep in
                            Text("\(rep) reps")
                                .tag(rep)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                }
                .presentationDetents([.fraction(0.3)])
                .presentationDragIndicator(.visible)
            }
            
            // 4. Completion Checkbox
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                withAnimation(.snappy) {
                    set.isCompleted.toggle()
                }
            }) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(set.isCompleted ? .green : .gray.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
