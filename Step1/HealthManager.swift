//
//  HealthManager.swift
//  Step1
//
//  Created by Alex Balakin on 1/19/26.
//

import SwiftUI
import HealthKit
import CoreLocation
import WidgetKit

class HealthManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let healthStore = HKHealthStore()
    let locationManager = CLLocationManager()
    
    @Published var steps: Int = 0
    @Published var distance: Double = 0.0
    @Published var duration: Int = 0
    @Published var goalReached: Bool = false
    @Published var dailyGoal: Int = 10000 {
        didSet {
            saveDailyGoal()
            loadDataForCurrentDate()
        }
    }
    @Published var weekStreak: [Bool] = Array(repeating: false, count: 7)
    @Published var weekProgress: [Double] = Array(repeating: 0.0, count: 7)
    @Published var streakCount: Int = 0
    @Published var maxStreak: Int = 0
    @Published var bestDaySteps: Int = 0
    @Published var bestDayDate: Date? = nil
    
    @Published var yesterdayDistance: Double = 0.0
    @Published var yesterdayDuration: Int = 0
    @Published var distanceChange: Double = 0.0
    @Published var durationChange: Double = 0.0
    
    var currentDate: Date = Date()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        loadDailyGoal()
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
    }
    
    func fetchStepsForDate(_ date: Date) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async {
                    self.steps = 0
                    self.goalReached = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.steps = Int(sum.doubleValue(for: HKUnit.count()))
                self.goalReached = self.steps >= self.dailyGoal
                
                // FIX #5: Cache current steps for widget fallback
                if Calendar.current.isDateInToday(date) {
                    UserDefaults(suiteName: "group.alex.Step1")?.set(self.steps, forKey: "lastKnownSteps")
                    UserDefaults(suiteName: "group.alex.Step1")?.set(Date().timeIntervalSince1970, forKey: "lastStepsUpdate")
                    // Trigger widget update
                    WidgetCenter.shared.reloadAllTimelines()
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
        let calendar = Calendar.current
        
        let currentWeekday = calendar.component(.weekday, from: currentDate)
        let daysFromMonday = currentWeekday == 1 ? 6 : currentWeekday - 2
        let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: currentDate))!
        
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
                let progress = min(Double(steps) / Double(self.dailyGoal), 1.0)
                
                tempResults[dayOffset] = (steps >= self.dailyGoal, progress)
            }
            
            self.healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.weekStreak = tempResults.map { $0.streak }
            self.weekProgress = tempResults.map { $0.progress }
        }
    }
    
    // MARK: - Global Streak (counts consecutive days from yesterday backwards)
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
}
