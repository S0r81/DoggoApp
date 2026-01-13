import ActivityKit
import WidgetKit
import SwiftUI

struct DoggoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoggoActivityAttributes.self) { context in
            // MARK: - Lock Screen / Notification Center UI
            HStack {
                Label("Rest Timer", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                // The Magic: iOS counts down automatically relative to the date
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            // MARK: - Dynamic Island UI
            DynamicIsland {
                // EXPANDED REGION (Long Press)
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundStyle(.yellow)
                        .padding(.trailing, 8)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Progress bar visualization
                    ProgressView(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .tint(.yellow)
                        .padding(.horizontal)
                }
                
            } compactLeading: {
                // COMPACT LEFT (Tiny Timer Icon)
                Image(systemName: "timer")
                    .foregroundStyle(.yellow)
                    .padding(.leading, 4)
                
            } compactTrailing: {
                // COMPACT RIGHT (The Countdown)
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 40)
                    .foregroundStyle(.yellow)
                
            } minimal: {
                // MINIMAL (When multiple apps are active)
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(.yellow)
            }
        }
    }
}
