//
//  HealthManager.swift
//  Step1
//
//  Created by Alex Balakin on 1/19/26.
//

import SwiftUI
import HealthKit
import CoreLocation
import CoreMotion
import WidgetKit
import ActivityKit

class HealthManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let healthStore = HKHealthStore()
    let locationManager = CLLocationManager()
    let pedometer = CMPedometer()
    
    @Published var steps: Int = 0
    @Published var distance: Double = 0.0
    @Published var duration: Int = 0
    @Published var goalReached: Bool = false
    @Published var shouldShowCelebration: Bool = false  // FIX #4: Trigger celebration popup
    @Published var dailyGoal: Int = 10000 {
        didSet {
            saveDailyGoal()
            // FIX #3: Check if goal change causes celebration (lowered goal and now reached)
            if Calendar.current.isDateInToday(currentDate) && steps >= dailyGoal && oldValue > dailyGoal {
                triggerCelebration()
            }
            loadDataForCurrentDate()
        }
    }
    @Published var weekStreak: [Bool] = Array(repeating: false, count: 7)
    @Published var weekProgress: [Double] = Array(repeating: 0.0, count: 7)
    @Published var streakCount: Int = 0
    @Published var maxStreak: Int = 0
    @Published var bestDaySteps: Int = 0
    @Published var bestDayDate: Date? = nil
    @Published var hourlyStepsToday: [Int] = Array(repeating: 0, count: 24)
    @Published var hourlyStepsYesterday: [Int] = Array(repeating: 0, count: 24)
    
    @Published var useMetric: Bool = true // true = km/kg, false = mi/lbs
    @Published var weekStartsMonday: Bool = true {
        didSet {
            // Recalculate week data when changed
            loadDataForCurrentDate()
        }
    }
    
    var appCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = weekStartsMonday ? 2 : 1 // 2 = Monday, 1 = Sunday
        return cal
    }
    
    @Published var yesterdayDistance: Double = 0.0
    @Published var yesterdayDuration: Int = 0
    @Published var distanceChange: Double = 0.0
    @Published var durationChange: Double = 0.0
    
    // Year progress data (12 months)
    @Published var yearProgress: [Double] = Array(repeating: 0.0, count: 12)
    @Published var yearGoalMet: [Bool] = Array(repeating: false, count: 12)
    
    // Quarter progress data (12 weeks)
    @Published var quarterProgress: [Double] = Array(repeating: 0.0, count: 12)
    @Published var quarterGoalMet: [Bool] = Array(repeating: false, count: 12)
    
    var currentDate: Date = Date()
    private var hasShownCelebrationToday: Bool = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        loadDailyGoal()
        // Load unit preference
        if UserDefaults.standard.object(forKey: "use_metric") != nil {
            useMetric = UserDefaults.standard.bool(forKey: "use_metric")
        }
        if UserDefaults.standard.object(forKey: "week_starts_monday") != nil {
            weekStartsMonday = UserDefaults.standard.bool(forKey: "week_starts_monday")
        }
        // Check if we've already shown celebration today
        let lastCelebrationDate = UserDefaults.standard.object(forKey: "lastCelebrationDate") as? Date
        if let lastDate = lastCelebrationDate, Calendar.current.isDateInToday(lastDate) {
            hasShownCelebrationToday = true
        }
    }
    
    // FIX #3: Helper to trigger celebration
    func triggerCelebration() {
        guard !hasShownCelebrationToday else { return }
        hasShownCelebrationToday = true
        UserDefaults.standard.set(Date(), forKey: "lastCelebrationDate")
        shouldShowCelebration = true
    }
    
    // FIX #4: Check on app launch if goal was reached while app was closed
    func checkCelebrationOnLaunch() {
        guard Calendar.current.isDateInToday(currentDate) else { return }
        guard !hasShownCelebrationToday else { return }
        
        if steps >= dailyGoal {
            // Goal was reached while app was closed — show with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.triggerCelebration()
            }
        }
    }
    
    func saveDailyGoal() {
        UserDefaults.standard.set(dailyGoal, forKey: "dailyStepGoal")
        // Save to App Group for widget
        UserDefaults(suiteName: "group.alex.Step1")?.set(dailyGoal, forKey: "dailyStepGoal")
        // Reload widget
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func loadDailyGoal() {
        let saved = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        if saved > 0 {
            dailyGoal = saved
        }
    }
    
    func requestAuthorization() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let exerciseTimeType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!
        
        let typesToRead: Set = [stepType, distanceType, activeEnergyType, exerciseTimeType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                self.loadDataForCurrentDate()
                // FIX #5: Enable background delivery for steps
                self.enableBackgroundDelivery()
                // FIX #5: Start observing step changes for real-time updates
                self.startObservingSteps()
            }
        }
        
        locationManager.requestWhenInUseAuthorization()
        
        // Request Motion & Fitness permission (CoreMotion)
        requestMotionPermission()
    }
    
    private func requestMotionPermission() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("Step counting not available")
            return
        }
        
        // This triggers the Motion & Fitness permission dialog
        pedometer.queryPedometerData(from: Date().addingTimeInterval(-86400), to: Date()) { data, error in
            if let error = error {
                print("Pedometer error: \(error.localizedDescription)")
            } else {
                print("Motion & Fitness permission granted")
            }
        }
    }
    
    // MARK: - FIX #5: Enable background delivery for widget updates
    private func enableBackgroundDelivery() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if let error = error {
                print("Background delivery error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - FIX #5: Observe step changes in real-time
    private var stepObserverQuery: HKObserverQuery?
    
    private func startObservingSteps() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        // Remove existing observer if any
        if let existing = stepObserverQuery {
            healthStore.stop(existing)
        }
        
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            
            // Re-fetch steps when HealthKit data changes
            DispatchQueue.main.async {
                self?.fetchStepsForDate(self?.currentDate ?? Date())
            }
            
            // Reload widget timeline
            WidgetCenter.shared.reloadAllTimelines()
            
            completionHandler()
        }
        
        stepObserverQuery = query
        healthStore.execute(query)
    }
    
    func loadDataForCurrentDate() {
        fetchStepsForDate(currentDate)
        let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
        fetchDistanceForDate(currentDate)
        fetchDistanceForDate(yesterdayDate, isYesterday: true)
        fetchDurationForDate(currentDate)
        fetchDurationForDate(yesterdayDate, isYesterday: true)
        fetchWeekStreak()
        calculateGlobalStreak()
        fetchBestDay()
        fetchHourlySteps(for: currentDate, isToday: true)
        fetchHourlySteps(for: yesterdayDate, isToday: false)
        fetchYearProgress()
        fetchQuarterProgress()
    }
    
    // MARK: - Fetch Year Progress (12 months)
    func fetchYearProgress() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let now = Date()
        
        var tempProgress: [Double] = Array(repeating: 0.0, count: 12)
        var tempGoalMet: [Bool] = Array(repeating: false, count: 12)
        let group = DispatchGroup()
        
        for monthOffset in 0..<12 {
            group.enter()
            
            // Calculate start and end of month
            var components = calendar.dateComponents([.year, .month], from: now)
            components.month! -= (11 - monthOffset)  // 0 = 11 months ago, 11 = current month
            
            guard let startOfMonth = calendar.date(from: components),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
                group.leave()
                continue
            }
            
            let endDate = min(endOfMonth, now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfMonth, end: calendar.date(byAdding: .day, value: 1, to: endDate), options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                defer { group.leave() }
                
                guard let result = result, let sum = result.sumQuantity() else { return }
                
                let totalSteps = Int(sum.doubleValue(for: HKUnit.count()))
                let daysInMonth = calendar.dateComponents([.day], from: startOfMonth, to: calendar.date(byAdding: .day, value: 1, to: endDate)!).day ?? 1
                let avgSteps = daysInMonth > 0 ? totalSteps / daysInMonth : 0
                let progress = Double(avgSteps) / Double(self.dailyGoal)
                
                tempProgress[monthOffset] = progress
                tempGoalMet[monthOffset] = progress >= 1.0
            }
            
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.yearProgress = tempProgress
            self.yearGoalMet = tempGoalMet
        }
    }
    
    // MARK: - Fetch Quarter Progress (12 weeks)
    func fetchQuarterProgress() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let now = Date()
        
        var tempProgress: [Double] = Array(repeating: 0.0, count: 12)
        var tempGoalMet: [Bool] = Array(repeating: false, count: 12)
        let group = DispatchGroup()
        
        for weekOffset in 0..<12 {
            group.enter()
            
            // Calculate start and end of week (weekOffset 0 = 11 weeks ago, 11 = current week)
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -(11 - weekOffset), to: now),
                  let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: weekStart)?.start else {
                group.leave()
                continue
            }
            
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? startOfWeek
            let endDate = min(endOfWeek, now)
            
            let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: endDate, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                defer { group.leave() }
                
                guard let result = result, let sum = result.sumQuantity() else { return }
                
                let totalSteps = Int(sum.doubleValue(for: HKUnit.count()))
                let daysInWeek = calendar.dateComponents([.day], from: startOfWeek, to: endDate).day ?? 1
                let avgSteps = daysInWeek > 0 ? totalSteps / max(daysInWeek, 1) : 0
                let progress = Double(avgSteps) / Double(self.dailyGoal)
                
                tempProgress[weekOffset] = progress
                tempGoalMet[weekOffset] = progress >= 1.0
            }
            
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.quarterProgress = tempProgress
            self.quarterGoalMet = tempGoalMet
        }
    }
    
    func fetchStepsForDate(_ date: Date) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // FIX #4: For past dates, use endOfDay. For today, use current time.
        let endDate = calendar.isDateInToday(date) ? Date() : endOfDay
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async {
                    self.steps = 0
                    self.goalReached = false
                }
                return
            }
            
            DispatchQueue.main.async {
                let wasGoalReached = self.goalReached
                
                self.steps = Int(sum.doubleValue(for: HKUnit.count()))
                self.goalReached = self.steps >= self.dailyGoal
                
                // FIX #3: Show celebration when goal is newly reached
                if calendar.isDateInToday(date) && self.goalReached && !wasGoalReached {
                    self.triggerCelebration()
                }
                
                // FIX #6: Cache current steps for widget
                if calendar.isDateInToday(date) {
                    UserDefaults(suiteName: "group.alex.Step1")?.set(self.steps, forKey: "lastKnownSteps")
                    UserDefaults(suiteName: "group.alex.Step1")?.set(Date().timeIntervalSince1970, forKey: "lastStepsUpdate")
                    WidgetCenter.shared.reloadAllTimelines()
                    
                    // Update Live Activity
                    if #available(iOS 16.1, *) {
                        self.updateLiveActivity()
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchDistanceForDate(_ date: Date, isYesterday: Bool = false) {
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async {
                    if isYesterday {
                        self.yesterdayDistance = 0.0
                    } else {
                        self.distance = 0.0
                    }
                    self.calculateDistanceChange()
                }
                return
            }
            
            DispatchQueue.main.async {
                let dist = sum.doubleValue(for: HKUnit.meterUnit(with: .kilo))
                if isYesterday {
                    self.yesterdayDistance = dist
                } else {
                    self.distance = dist
                }
                self.calculateDistanceChange()
            }
        }
        
        healthStore.execute(query)
    }
    
    func calculateDistanceChange() {
        if yesterdayDistance > 0 {
            distanceChange = ((distance - yesterdayDistance) / yesterdayDistance) * 100
        } else {
            distanceChange = distance > 0 ? 100 : 0
        }
    }
    
    func fetchDurationForDate(_ date: Date, isYesterday: Bool = false) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: stepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            guard let samples = samples as? [HKQuantitySample] else {
                DispatchQueue.main.async {
                    if isYesterday {
                        self.yesterdayDuration = 0
                    } else {
                        self.duration = 0
                    }
                    self.calculateDurationChange()
                }
                return
            }
            
            var activeMinutes = 0
            let grouped = Dictionary(grouping: samples) { sample -> Date in
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: sample.startDate)
                let roundedMinute = (components.minute ?? 0) / 5 * 5
                return calendar.date(from: DateComponents(
                    year: components.year,
                    month: components.month,
                    day: components.day,
                    hour: components.hour,
                    minute: roundedMinute
                )) ?? sample.startDate
            }
            
            activeMinutes = grouped.count * 5
            
            DispatchQueue.main.async {
                if isYesterday {
                    self.yesterdayDuration = activeMinutes
                } else {
                    self.duration = activeMinutes
                }
                self.calculateDurationChange()
            }
        }
        
        healthStore.execute(query)
    }
    
    func calculateDurationChange() {
        if yesterdayDuration > 0 {
            durationChange = ((Double(duration) - Double(yesterdayDuration)) / Double(yesterdayDuration)) * 100
        } else {
            durationChange = duration > 0 ? 100 : 0
        }
    }
    
    func fetchWeekStreak() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = appCalendar
        
        // Calculate week start based on appCalendar.firstWeekday
        let currentWeekday = calendar.component(.weekday, from: currentDate)
        let firstDay = calendar.firstWeekday // 2 for Monday, 1 for Sunday
        var daysFromStart = currentWeekday - firstDay
        if daysFromStart < 0 { daysFromStart += 7 }
        let weekStart = calendar.date(byAdding: .day, value: -daysFromStart, to: calendar.startOfDay(for: currentDate))!
        
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        
        var tempResults: [(streak: Bool, progress: Double)] = Array(repeating: (false, 0.0), count: 7)
        let group = DispatchGroup()
        
        for dayOffset in 0..<7 {
            let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let dayStartOfDay = calendar.startOfDay(for: dayStart)
            
            if dayStartOfDay > todayStart {
                continue
            }
            
            group.enter()
            
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                defer { group.leave() }
                
                guard let result = result, let sum = result.sumQuantity() else {
                    return
                }
                
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                let progress = Double(steps) / Double(self.dailyGoal)
                
                tempResults[dayOffset] = (steps >= self.dailyGoal, progress)
            }
            
            self.healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.weekStreak = tempResults.map { $0.streak }
            self.weekProgress = tempResults.map { $0.progress }
            self.fetchLast7DaysProgress()
        }
    }
    
    // MARK: - Last 7 days progress (today = rightmost)
    @Published var last7DaysProgress: [Double] = Array(repeating: 0.0, count: 7)
    @Published var last7DaysLabels: [String] = Array(repeating: "", count: 7)
    @Published var last7DaysGoalMet: [Bool] = Array(repeating: false, count: 7)
    
    func fetchLast7DaysProgress() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let dayAbbrs = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        
        var tempProgress: [Double] = Array(repeating: 0.0, count: 7)
        var tempLabels: [String] = Array(repeating: "", count: 7)
        var tempGoalMet: [Bool] = Array(repeating: false, count: 7)
        let group = DispatchGroup()
        
        for i in 0..<7 {
            // i=0 is 6 days ago, i=6 is today
            let dayStart = calendar.date(byAdding: .day, value: -(6 - i), to: today)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let weekday = calendar.component(.weekday, from: dayStart) // 1=Sun...7=Sat
            tempLabels[i] = dayAbbrs[weekday - 1]
            
            group.enter()
            
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                defer { group.leave() }
                if let sum = result?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    tempProgress[i] = Double(steps) / Double(self.dailyGoal)
                    tempGoalMet[i] = steps >= self.dailyGoal
                }
            }
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.last7DaysProgress = tempProgress
            self.last7DaysLabels = tempLabels
            self.last7DaysGoalMet = tempGoalMet
        }
    }
    
    // MARK: - Global Streak (counts consecutive days from yesterday backwards)
    
    // MARK: - Week Summary (for W tab)
    @Published var weekSummaryTotal: Int = 0
    @Published var weekSummaryDailySteps: [Int] = Array(repeating: 0, count: 7)  // Mon-Sun
    @Published var weekSummaryDailyGoalMet: [Bool] = Array(repeating: false, count: 7)
    @Published var weekSummaryAvg: Int = 0
    @Published var weekSummaryPrevAvg: Int = 0
    @Published var weekSummaryStartDate: Date = Date()
    @Published var weekSummaryEndDate: Date = Date()
    @Published var weekSummaryTotalDistance: Double = 0.0  // km
    @Published var weekSummaryTotalDuration: Int = 0       // seconds
    @Published var weekSummaryTotalCalories: Double = 0.0
    var weekOffset: Int = 0  // 0 = current week, -1 = last week, etc.
    
    func fetchWeekSummary(offset: Int = 0) {
        self.weekOffset = offset
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = appCalendar
        
        // Find Monday (or Sunday if weekStartsMonday=false) of current week
        let today = calendar.startOfDay(for: Date())
        let currentWeekday = calendar.component(.weekday, from: today)
        let firstDay = calendar.firstWeekday
        var daysFromStart = currentWeekday - firstDay
        if daysFromStart < 0 { daysFromStart += 7 }
        let thisWeekStart = calendar.date(byAdding: .day, value: -daysFromStart, to: today)!
        
        // Apply offset
        let weekStart = calendar.date(byAdding: .day, value: offset * 7, to: thisWeekStart)!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        
        DispatchQueue.main.async {
            self.weekSummaryStartDate = weekStart
            self.weekSummaryEndDate = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        }
        
        let todayStart = calendar.startOfDay(for: Date())
        
        var tempSteps: [Int] = Array(repeating: 0, count: 7)
        var tempGoalMet: [Bool] = Array(repeating: false, count: 7)
        let group = DispatchGroup()
        
        for dayIdx in 0..<7 {
            let dayStart = calendar.date(byAdding: .day, value: dayIdx, to: weekStart)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            if calendar.startOfDay(for: dayStart) > todayStart { continue }
            
            group.enter()
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                defer { group.leave() }
                if let sum = result?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    tempSteps[dayIdx] = steps
                    tempGoalMet[dayIdx] = steps >= self.dailyGoal
                }
            }
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.weekSummaryDailySteps = tempSteps
            self.weekSummaryDailyGoalMet = tempGoalMet
            let total = tempSteps.reduce(0, +)
            self.weekSummaryTotal = total
            let activeDays = tempSteps.filter { $0 > 0 }.count
            self.weekSummaryAvg = activeDays > 0 ? total / activeDays : 0
            
            // Distance, time, calories for week
            let totalSteps = Double(total)
            self.weekSummaryTotalDistance = totalSteps * 0.00075
            self.weekSummaryTotalDuration = Int((totalSteps * 0.00075 / 5.0) * 3600.0)
            self.weekSummaryTotalCalories = totalSteps * 0.045
            
            // Fetch previous week avg for comparison
            self.fetchPrevWeekAvg(prevWeekStart: calendar.date(byAdding: .day, value: -7, to: weekStart)!)
        }
    }
    
    private func fetchPrevWeekAvg(prevWeekStart: Date) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = appCalendar
        let todayStart = calendar.startOfDay(for: Date())
        
        var tempSteps: [Int] = Array(repeating: 0, count: 7)
        let group = DispatchGroup()
        
        for dayIdx in 0..<7 {
            let dayStart = calendar.date(byAdding: .day, value: dayIdx, to: prevWeekStart)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            if calendar.startOfDay(for: dayStart) > todayStart { continue }
            
            group.enter()
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                defer { group.leave() }
                if let sum = result?.sumQuantity() {
                    tempSteps[dayIdx] = Int(sum.doubleValue(for: HKUnit.count()))
                }
            }
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            let total = tempSteps.reduce(0, +)
            let activeDays = tempSteps.filter { $0 > 0 }.count
            self.weekSummaryPrevAvg = activeDays > 0 ? total / activeDays : 0
        }
    }
    
    // MARK: - Month Summary (for M tab)
    @Published var monthSummaryTotal: Int = 0
    @Published var monthSummaryDailySteps: [Int] = []        // 28-31 values
    @Published var monthSummaryDailyGoalMet: [Bool] = []
    @Published var monthSummaryAvg: Int = 0
    @Published var monthSummaryPrevAvg: Int = 0
    @Published var monthSummaryMonth: Date = Date()          // 1st of displayed month
    @Published var monthSummaryTotalDistance: Double = 0.0
    @Published var monthSummaryTotalDuration: Int = 0
    @Published var monthSummaryTotalCalories: Double = 0.0
    var monthOffset: Int = 0
    
    func fetchMonthSummary(offset: Int = 0) {
        self.monthOffset = offset
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Find 1st of current month
        let components = calendar.dateComponents([.year, .month], from: today)
        let thisMonth1st = calendar.date(from: components)!
        
        // Apply offset
        let targetMonth1st = calendar.date(byAdding: .month, value: offset, to: thisMonth1st)!
        let daysInMonth = calendar.range(of: .day, in: .month, for: targetMonth1st)!.count
        
        DispatchQueue.main.async {
            self.monthSummaryMonth = targetMonth1st
        }
        
        var tempSteps: [Int] = Array(repeating: 0, count: daysInMonth)
        var tempGoalMet: [Bool] = Array(repeating: false, count: daysInMonth)
        let group = DispatchGroup()
        
        for dayIdx in 0..<daysInMonth {
            let dayStart = calendar.date(byAdding: .day, value: dayIdx, to: targetMonth1st)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            if calendar.startOfDay(for: dayStart) > today { continue }
            
            group.enter()
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                defer { group.leave() }
                if let sum = result?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    tempSteps[dayIdx] = steps
                    tempGoalMet[dayIdx] = steps >= self.dailyGoal
                }
            }
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.monthSummaryDailySteps = tempSteps
            self.monthSummaryDailyGoalMet = tempGoalMet
            let total = tempSteps.reduce(0, +)
            self.monthSummaryTotal = total
            let activeDays = tempSteps.filter { $0 > 0 }.count
            self.monthSummaryAvg = activeDays > 0 ? total / activeDays : 0
            
            let totalStepsD = Double(total)
            self.monthSummaryTotalDistance = totalStepsD * 0.00075
            self.monthSummaryTotalDuration = Int((totalStepsD * 0.00075 / 5.0) * 3600.0)
            self.monthSummaryTotalCalories = totalStepsD * 0.045
            
            // Previous month avg
            self.fetchPrevMonthAvg(prevMonth1st: calendar.date(byAdding: .month, value: -1, to: targetMonth1st)!)
        }
    }
    
    private func fetchPrevMonthAvg(prevMonth1st: Date) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let daysInMonth = calendar.range(of: .day, in: .month, for: prevMonth1st)!.count
        
        var tempSteps: [Int] = Array(repeating: 0, count: daysInMonth)
        let group = DispatchGroup()
        
        for dayIdx in 0..<daysInMonth {
            let dayStart = calendar.date(byAdding: .day, value: dayIdx, to: prevMonth1st)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            if calendar.startOfDay(for: dayStart) > todayStart { continue }
            
            group.enter()
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                defer { group.leave() }
                if let sum = result?.sumQuantity() {
                    tempSteps[dayIdx] = Int(sum.doubleValue(for: HKUnit.count()))
                }
            }
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            let total = tempSteps.reduce(0, +)
            let activeDays = tempSteps.filter { $0 > 0 }.count
            self.monthSummaryPrevAvg = activeDays > 0 ? total / activeDays : 0
        }
    }
    
    func calculateGlobalStreak() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let group = DispatchGroup()
        var results: [Date: Bool] = [:]
        
        // Check up to 365 days back for streak and max streak
        let daysToCheck = 365
        
        for i in 0..<daysToCheck {
            let dayToCheck = calendar.date(byAdding: .day, value: -i, to: calendar.date(byAdding: .day, value: -1, to: today)!)!
            let dayStart = calendar.startOfDay(for: dayToCheck)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            group.enter()
            
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                defer { group.leave() }
                
                let steps: Int
                if let sum = result?.sumQuantity() {
                    steps = Int(sum.doubleValue(for: HKUnit.count()))
                } else {
                    steps = 0
                }
                
                DispatchQueue.main.async {
                    results[dayStart] = steps >= self.dailyGoal
                }
            }
            
            self.healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            // Count current streak (consecutive days from yesterday)
            var currentCount = 0
            for i in 0..<daysToCheck {
                let dayToCheck = calendar.date(byAdding: .day, value: -i - 1, to: today)!
                let dayStart = calendar.startOfDay(for: dayToCheck)
                
                if results[dayStart] == true {
                    currentCount += 1
                } else {
                    break
                }
            }
            self.streakCount = currentCount
            
            // Calculate max streak
            var maxCount = 0
            var tempCount = 0
            for i in 0..<daysToCheck {
                let dayToCheck = calendar.date(byAdding: .day, value: -i - 1, to: today)!
                let dayStart = calendar.startOfDay(for: dayToCheck)
                
                if results[dayStart] == true {
                    tempCount += 1
                    maxCount = max(maxCount, tempCount)
                } else {
                    tempCount = 0
                }
            }
            self.maxStreak = max(maxCount, currentCount)
        }
    }
    
    // MARK: - Fetch Best Day (highest step count in last 365 days)
    func fetchBestDay() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysToCheck = 365
        
        let group = DispatchGroup()
        var daySteps: [(date: Date, steps: Int)] = []
        let lock = NSLock()
        
        for i in 0..<daysToCheck {
            let dayStart = calendar.date(byAdding: .day, value: -i, to: today)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            group.enter()
            
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                defer { group.leave() }
                
                if let sum = result?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    if steps > 0 {
                        lock.lock()
                        daySteps.append((date: dayStart, steps: steps))
                        lock.unlock()
                    }
                }
            }
            
            self.healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            if let best = daySteps.max(by: { $0.steps < $1.steps }) {
                self.bestDaySteps = best.steps
                self.bestDayDate = best.date
            }
        }
    }
    
    // MARK: - Fetch Hourly Steps for Day Progress Chart
    func fetchHourlySteps(for date: Date, isToday: Bool) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        let group = DispatchGroup()
        var hourlyResults = Array(repeating: 0, count: 24)
        let lock = NSLock()
        
        for hour in 0..<24 {
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart)!
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
            
            group.enter()
            
            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                defer { group.leave() }
                
                if let sum = result?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    lock.lock()
                    hourlyResults[hour] = steps
                    lock.unlock()
                }
            }
            
            self.healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            if isToday {
                self.hourlyStepsToday = hourlyResults
            } else {
                self.hourlyStepsYesterday = hourlyResults
            }
        }
    }
    
    var progress: Double {
        return min(Double(steps) / Double(dailyGoal), 1.0)
    }
    
    var percentageOverGoal: String {
        if steps >= dailyGoal {
            let percent = ((Double(steps) - Double(dailyGoal)) / Double(dailyGoal)) * 100
            return String(format: "+ %.1f%%", percent)
        }
        return "0%"
    }
    // MARK: - Check if day is completed
        func isDayCompleted(_ date: Date) -> Bool {
            let calendar = Calendar.current
            let dateStart = calendar.startOfDay(for: date)
            let today = calendar.startOfDay(for: Date())
            
            // Будущие даты не могут быть завершены
            if dateStart > today {
                return false
            }
            
            // Для текущей даты используем уже загруженные данные
            if dateStart == calendar.startOfDay(for: currentDate) {
                return steps >= dailyGoal
            }
            
            // Для других дат проверяем weekStreak если это текущая неделя
            let currentWeekday = calendar.component(.weekday, from: currentDate)
            let daysFromMonday = currentWeekday == 1 ? 6 : currentWeekday - 2
            let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: currentDate))!
            
            if let daysDiff = calendar.dateComponents([.day], from: weekStart, to: dateStart).day,
               daysDiff >= 0 && daysDiff < 7 {
                return weekStreak[daysDiff]
            }
            
            return false
        }
    
    // MARK: - Calendar day progress cache
    @Published var dayProgressCache: [String: Double] = [:] // "yyyy-MM-dd" -> progress 0.0...1.0+
    
    func fetchMonthProgress(for month: Date) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return }
        
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var tempCache: [String: Double] = [:]
        let group = DispatchGroup()
        
        var current = interval.start
        while current < interval.end && current <= today {
            let dayStart = current
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let dateKey = formatter.string(from: dayStart)
            
            group.enter()
            
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                defer { group.leave() }
                if let sum = result?.sumQuantity() {
                    let steps = sum.doubleValue(for: HKUnit.count())
                    let progress = self.dailyGoal > 0 ? steps / Double(self.dailyGoal) : 0
                    tempCache[dateKey] = progress
                } else {
                    tempCache[dateKey] = 0
                }
            }
            healthStore.execute(query)
            current = dayEnd
        }
        
        group.notify(queue: .main) {
            self.dayProgressCache.merge(tempCache) { _, new in new }
        }
    }
    
    func progressForDate(_ date: Date) -> Double {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        
        // For current date use live data
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: currentDate) {
            return dailyGoal > 0 ? Double(steps) / Double(dailyGoal) : 0
        }
        
        return dayProgressCache[key] ?? 0
    }
    
    // MARK: - Get historical steps for Firestore sync
    func getHistoricalSteps(days: Int = 30, completion: @escaping ([String: Int]) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var stepsHistory: [String: Int] = [:]
        let group = DispatchGroup()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for i in 0..<days {
            let dayStart = calendar.date(byAdding: .day, value: -i, to: today)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let dateKey = formatter.string(from: dayStart)
            
            group.enter()
            
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                defer { group.leave() }
                
                if let sum = result?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    stepsHistory[dateKey] = steps
                }
            }
            
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            completion(stepsHistory)
        }
    }
    
    // MARK: - Live Activities
    
    @available(iOS 16.1, *)
    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }
        
        // End any existing activities first
        endLiveActivity()
        
        let attributes = StepWidgetAttributes(userName: "User")
        let state = StepWidgetAttributes.ContentState(
            steps: steps,
            goal: dailyGoal,
            progress: progress
        )
        
        do {
            let activity = try Activity<StepWidgetAttributes>.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
            print("Started Live Activity: \(activity.id)")
        } catch {
            print("Error starting Live Activity: \(error)")
        }
    }
    
    @available(iOS 16.1, *)
    func updateLiveActivity() {
        Task {
            let state = StepWidgetAttributes.ContentState(
                steps: steps,
                goal: dailyGoal,
                progress: progress
            )
            
            for activity in Activity<StepWidgetAttributes>.activities {
                await activity.update(using: state)
            }
        }
    }
    
    @available(iOS 16.1, *)
    func endLiveActivity() {
        Task {
            for activity in Activity<StepWidgetAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
