//
//  StepWidget.swift
//  StepWidget
//
//  Created by Alex Balakin
//

import WidgetKit
import SwiftUI
import HealthKit

// MARK: - Widget Entry
struct StepEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let goal: Int
    let progress: Double
    let goalReached: Bool
    let multiplier: Int
}

// MARK: - Timeline Provider
struct StepProvider: TimelineProvider {
    let healthStore = HKHealthStore()
    
    func placeholder(in context: Context) -> StepEntry {
        StepEntry(date: Date(), steps: 8765, goal: 10000, progress: 0.87, goalReached: false, multiplier: 0)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (StepEntry) -> Void) {
        fetchSteps { steps in
            let goal = UserDefaults(suiteName: "group.alex.Step1")?.integer(forKey: "dailyStepGoal") ?? 10000
            let actualGoal = goal > 0 ? goal : 10000
            let progress = min(Double(steps) / Double(actualGoal), 1.0)
            let goalReached = steps >= actualGoal
            let multiplier = actualGoal > 0 ? steps / actualGoal : 0
            
            let entry = StepEntry(
                date: Date(),
                steps: steps,
                goal: actualGoal,
                progress: progress,
                goalReached: goalReached,
                multiplier: multiplier
            )
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StepEntry>) -> Void) {
        fetchSteps { steps in
            let goal = UserDefaults(suiteName: "group.alex.Step1")?.integer(forKey: "dailyStepGoal") ?? 10000
            let actualGoal = goal > 0 ? goal : 10000
            let progress = min(Double(steps) / Double(actualGoal), 1.0)
            let goalReached = steps >= actualGoal
            let multiplier = actualGoal > 0 ? steps / actualGoal : 0
            
            let entry = StepEntry(
                date: Date(),
                steps: steps,
                goal: actualGoal,
                progress: progress,
                goalReached: goalReached,
                multiplier: multiplier
            )
            
            // FIX #5: More frequent updates + multiple entries for better stability
            let calendar = Calendar.current
            var entries: [StepEntry] = [entry]
            
            // Add future entries every 5 minutes for the next 30 minutes
            for minuteOffset in stride(from: 5, through: 30, by: 5) {
                if let futureDate = calendar.date(byAdding: .minute, value: minuteOffset, to: Date()) {
                    entries.append(StepEntry(
                        date: futureDate,
                        steps: steps,
                        goal: actualGoal,
                        progress: progress,
                        goalReached: goalReached,
                        multiplier: multiplier
                    ))
                }
            }
            
            // Request update after the last entry
            let nextUpdate = calendar.date(byAdding: .minute, value: 5, to: Date())!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    func fetchSteps(completion: @escaping (Int) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(0)
            return
        }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        // FIX #5: Request authorization first (needed for widget extension)
        healthStore.requestAuthorization(toShare: nil, read: [stepType]) { success, error in
            guard success else {
                DispatchQueue.main.async { completion(0) }
                return
            }
            
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                DispatchQueue.main.async {
                    guard let result = result, let sum = result.sumQuantity() else {
                        // FIX #5: Fall back to cached value instead of 0
                        let cached = UserDefaults(suiteName: "group.alex.Step1")?.integer(forKey: "lastKnownSteps") ?? 0
                        completion(cached)
                        return
                    }
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    // FIX #5: Cache steps for fallback
                    UserDefaults(suiteName: "group.alex.Step1")?.set(steps, forKey: "lastKnownSteps")
                    UserDefaults(suiteName: "group.alex.Step1")?.set(Date().timeIntervalSince1970, forKey: "lastStepsUpdate")
                    completion(steps)
                }
            }
            
            self.healthStore.execute(query)
        }
    }
}

// MARK: - Widget View
struct StepWidgetEntryView: View {
    var entry: StepProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var currentProgress: Double {
        if entry.multiplier == 0 {
            return entry.progress
        }
        let remainder = entry.steps % entry.goal
        return Double(remainder) / Double(entry.goal)
    }
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry, currentProgress: currentProgress)
        case .systemMedium:
            MediumWidgetView(entry: entry, currentProgress: currentProgress)
        default:
            SmallWidgetView(entry: entry, currentProgress: currentProgress)
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let entry: StepEntry
    let currentProgress: Double
    
    private let circleSize: CGFloat = 100
    private let badgeSize: CGFloat = 16
    
    var body: some View {
        ZStack {
            // Progress circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(red: 44/255, green: 44/255, blue: 46/255), lineWidth: 8)
                    .frame(width: circleSize, height: circleSize)
                
                // Progress circle
                if entry.multiplier == 0 {
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(
                            Color(red: 52/255, green: 199/255, blue: 89/255),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: circleSize, height: circleSize)
                        .rotationEffect(.degrees(-90))
                } else {
                    // Full circle when goal reached
                    Circle()
                        .stroke(Color(red: 52/255, green: 199/255, blue: 89/255), lineWidth: 8)
                        .frame(width: circleSize, height: circleSize)
                    
                    // Inner progress for multiplier
                    if currentProgress > 0 {
                        Circle()
                            .trim(from: 0, to: currentProgress)
                            .stroke(
                                Color(red: 52/255, green: 199/255, blue: 89/255),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                    }
                }
                
                // Steps text
                Text("\(entry.steps.formatted())")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                
                // Badge in top right corner, outside the ring
                if entry.goalReached {
                    ZStack {
                        Circle()
                            .fill(Color(red: 52/255, green: 199/255, blue: 89/255))
                            .frame(width: badgeSize, height: badgeSize)
                        
                        if entry.multiplier > 1 {
                            Text("\(entry.multiplier)x")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.black)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .offset(x: 52, y: -52)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let entry: StepEntry
    let currentProgress: Double
    
    var body: some View {
        ZStack {
            HStack(spacing: 20) {
                // Circle
                ZStack {
                    Circle()
                        .stroke(Color(red: 44/255, green: 44/255, blue: 46/255), lineWidth: 12)
                        .frame(width: 130, height: 130)
                    
                    if entry.multiplier == 0 {
                        Circle()
                            .trim(from: 0, to: entry.progress)
                            .stroke(
                                Color(red: 52/255, green: 199/255, blue: 89/255),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 130, height: 130)
                            .rotationEffect(.degrees(-90))
                    } else {
                        Circle()
                            .stroke(Color(red: 52/255, green: 199/255, blue: 89/255), lineWidth: 12)
                            .frame(width: 130, height: 130)
                        
                        if currentProgress > 0 {
                            Circle()
                                .trim(from: 0, to: currentProgress)
                                .stroke(
                                    Color(red: 52/255, green: 199/255, blue: 89/255),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .frame(width: 102, height: 102)
                                .rotationEffect(.degrees(-90))
                        }
                    }
                    
                    Text("\(entry.steps.formatted())")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    if entry.goalReached {
                        Circle()
                            .fill(Color(red: 52/255, green: 199/255, blue: 89/255))
                            .frame(width: 18, height: 18)
                            .offset(y: -72)
                    }
                }
                
                // Stats
                VStack(alignment: .leading, spacing: 8) {
                    Text("Steps")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 142/255, green: 142/255, blue: 147/255))
                    
                    Text("\(entry.steps.formatted())")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Goal \(entry.goal.formatted())")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 142/255, green: 142/255, blue: 147/255))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

// MARK: - Widget Configuration
struct StepWidget: Widget {
    let kind: String = "StepWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepProvider()) { entry in
            StepWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("StePlease")
        .description("Track your daily steps")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    StepWidget()
} timeline: {
    StepEntry(date: Date(), steps: 8765, goal: 10000, progress: 0.87, goalReached: false, multiplier: 0)
    StepEntry(date: Date(), steps: 12500, goal: 10000, progress: 1.0, goalReached: true, multiplier: 1)
    StepEntry(date: Date(), steps: 25000, goal: 10000, progress: 1.0, goalReached: true, multiplier: 2)
}
