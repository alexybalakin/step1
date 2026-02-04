//
//  StepWidgetLiveActivity.swift
//  StepWidget
//
//  Created by Alex Balakin on 1/22/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget
struct StepWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StepWidgetAttributes.self) { context in
            // Lock screen / banner UI
            HStack(spacing: 16) {
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: min(context.state.progress, 1.0))
                        .stroke(Color(hex: "34C759"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "34C759"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(context.state.steps.formatted()) steps")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Goal: \(context.state.goal.formatted())")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Percentage
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(context.state.progress >= 1.0 ? Color(hex: "34C759") : .white)
            }
            .padding(16)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .foregroundColor(Color(hex: "34C759"))
                            .font(.system(size: 24))
                        
                        VStack(alignment: .leading) {
                            Text("\(context.state.steps.formatted())")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("steps")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("\(Int(context.state.progress * 100))%")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(context.state.progress >= 1.0 ? Color(hex: "34C759") : .white)
                        Text("of \(context.state.goal.formatted())")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "34C759"))
                                .frame(width: geo.size.width * min(context.state.progress, 1.0), height: 8)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 8)
                }
                
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundColor(Color(hex: "34C759"))
            } compactTrailing: {
                Text("\(context.state.steps.formatted())")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundColor(Color(hex: "34C759"))
            }
        }
    }
}

// MARK: - Color Extension for Widget
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Preview
extension StepWidgetAttributes {
    fileprivate static var preview: StepWidgetAttributes {
        StepWidgetAttributes(userName: "User")
    }
}

extension StepWidgetAttributes.ContentState {
    fileprivate static var inProgress: StepWidgetAttributes.ContentState {
        StepWidgetAttributes.ContentState(steps: 7206, goal: 10000, progress: 0.72)
    }
    
    fileprivate static var goalReached: StepWidgetAttributes.ContentState {
        StepWidgetAttributes.ContentState(steps: 12500, goal: 10000, progress: 1.25)
    }
}

#Preview("Notification", as: .content, using: StepWidgetAttributes.preview) {
    StepWidgetLiveActivity()
} contentStates: {
    StepWidgetAttributes.ContentState.inProgress
    StepWidgetAttributes.ContentState.goalReached
}
