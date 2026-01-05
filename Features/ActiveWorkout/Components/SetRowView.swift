import SwiftUI

struct SetRowView: View {
    @Bindable var set: WorkoutSet
    var index: Int
    
    // Controls for the two pickers
    @State private var showWeightPicker = false
    @State private var showRepsPicker = false
    
    // Data sources for the wheels
    // Weight: 0 to 600 in 5lb steps
    let weightOptions: [Double] = Array(stride(from: 0, through: 600, by: 5.0))
    // Reps: 0 to 100
    let repsOptions: [Int] = Array(0...100)
    
    var body: some View {
        HStack {
            // 1. Set Number
            Text("\(index)")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            // 2. Weight Input (Triggers Weight Sheet)
            Button(action: {
                showWeightPicker = true
            }) {
                VStack(spacing: 2) {
                    Text("\(set.weight, format: .number)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    
                    Text("lbs")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showWeightPicker) {
                VStack {
                    Text("Select Weight")
                        .font(.headline)
                        .padding(.top)
                    
                    Picker("Weight", selection: $set.weight) {
                        ForEach(weightOptions, id: \.self) { weight in
                            Text("\(weight, format: .number) lbs")
                                .tag(weight)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                }
                .presentationDetents([.fraction(0.3)])
                .presentationDragIndicator(.visible)
            }
            
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
                .frame(width: 70) // Fixed width for reps looks cleaner
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
