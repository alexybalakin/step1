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
        let defaults = UserDefaults(suiteName: "group.alex.Step1")
        let goal = defaults?.integer(forKey: "dailyStepGoal") ?? 10000
        let actualGoal = goal > 0 ? goal : 10000

        // Return placeholder entry for preview
        if context.isPreview {
            completion(StepEntry(date: Date(), steps: 8765, goal: actualGoal, progress: 0.87, goalReached: false, multiplier: 0))
            return
        }

        fetchSteps { steps in
            let finalSteps = max(steps, 0)
            let progress = min(Double(finalSteps) / Double(actualGoal), 1.0)
            let goalReached = finalSteps >= actualGoal
            let multiplier = actualGoal > 0 ? finalSteps / actualGoal : 0
            
            let entry = StepEntry(
                date: Date(),
                steps: finalSteps,
                goal: actualGoal,
                progress: progress,
                goalReached: goalReached,
                multiplier: multiplier
            )
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StepEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.alex.Step1")
        let goal = defaults?.integer(forKey: "dailyStepGoal") ?? 10000
        let actualGoal = goal > 0 ? goal : 10000

        fetchSteps { steps in
            let finalSteps = max(steps, 0)
            let progress = min(Double(finalSteps) / Double(actualGoal), 1.0)
            let goalReached = finalSteps >= actualGoal
            let multiplier = actualGoal > 0 ? finalSteps / actualGoal : 0

            let calendar = Calendar.current
            let now = Date()
            var entries: [StepEntry] = []

            // Current entry
            entries.append(StepEntry(
                date: now,
                steps: finalSteps,
                goal: actualGoal,
                progress: progress,
                goalReached: goalReached,
                multiplier: multiplier
            ))

            // Future entries every 5 minutes for the next 30 minutes
            for minuteOffset in stride(from: 5, through: 30, by: 5) {
                if let futureDate = calendar.date(byAdding: .minute, value: minuteOffset, to: now) {
                    entries.append(StepEntry(
                        date: futureDate,
                        steps: finalSteps,
                        goal: actualGoal,
                        progress: progress,
                        goalReached: goalReached,
                        multiplier: multiplier
                    ))
                }
            }

            // Add a midnight reset entry — show 0 steps at start of new day
            let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
            entries.append(StepEntry(
                date: tomorrow,
                steps: 0,
                goal: actualGoal,
                progress: 0,
                goalReached: false,
                multiplier: 0
            ))

            // Request next update in 5 minutes, or at midnight if it's sooner
            let fiveMinLater = calendar.date(byAdding: .minute, value: 5, to: now)!
            let nextUpdate = min(fiveMinLater, tomorrow)
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    func fetchSteps(completion: @escaping (Int) -> Void) {
        let defaults = UserDefaults(suiteName: "group.alex.Step1")
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        // Read cached value from App Group (written by main app)
        let cachedSteps = defaults?.integer(forKey: "lastKnownSteps") ?? 0
        let lastUpdate = defaults?.double(forKey: "lastStepsUpdate") ?? 0

        // Check if cache is from today
        let cacheIsFromToday: Bool
        if lastUpdate > 0 {
            let lastDate = Date(timeIntervalSince1970: lastUpdate)
            cacheIsFromToday = calendar.isDate(lastDate, inSameDayAs: now)
        } else {
            cacheIsFromToday = false
        }

        // If cache is stale (from yesterday), treat as 0
        let todayCachedSteps = cacheIsFromToday ? cachedSteps : 0

        guard HKHealthStore.isHealthDataAvailable() else {
            completion(todayCachedSteps)
            return
        }

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        // Use HKStatisticsCollectionQuery to match Apple Health's values
        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startOfDay,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            let stats = results?.statistics(for: startOfDay)
            let hkSteps: Int
            if let sum = stats?.sumQuantity() {
                hkSteps = Int(sum.doubleValue(for: HKUnit.count()))
            } else {
                hkSteps = 0
            }

            // Use the best value: max of HK query and today's cache
            // This prevents HK returning 0 (auth issue) from wiping good cached data
            let finalSteps = max(hkSteps, todayCachedSteps)

            // Only update cache if we got a real HK value (don't overwrite with 0)
            if hkSteps > 0 {
                defaults?.set(hkSteps, forKey: "lastKnownSteps")
                defaults?.set(Date().timeIntervalSince1970, forKey: "lastStepsUpdate")
            }

            completion(finalSteps)
        }

        healthStore.execute(query)
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
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
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
                
                // Steps text - always show something
                Text(entry.steps > 0 ? entry.steps.formatted() : "—")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(entry.steps > 0 ? .white : Color(red: 142/255, green: 142/255, blue: 147/255))
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

// MARK: - Lock Screen Circular Widget
struct AccessoryCircularView: View {
    let entry: StepEntry

    private var progress: Double {
        guard entry.goal > 0 else { return 0 }
        return min(Double(entry.steps) / Double(entry.goal), 1.0)
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: 4)
                .opacity(0.3)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Step count
            Text(abbreviatedSteps(entry.steps))
                .font(.system(size: 12, weight: .bold))
                .minimumScaleFactor(0.5)
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private func abbreviatedSteps(_ steps: Int) -> String {
        if steps >= 10000 {
            let k = Double(steps) / 1000.0
            return String(format: "%.0fk", k)
        } else if steps >= 1000 {
            let k = Double(steps) / 1000.0
            if k == Double(Int(k)) {
                return String(format: "%.0fk", k)
            }
            return String(format: "%.1fk", k)
        }
        return "\(steps)"
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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
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
