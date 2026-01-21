//
//  HealthManager.swift
//  Step1
//
//  Created by Alex Balakin on 1/19/26.
//

import SwiftUI
import HealthKit
import CoreLocation

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
    
    private func saveDailyGoal() {
        UserDefaults.standard.set(dailyGoal, forKey: "dailyStepGoal")
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
            }
        }
        
        locationManager.requestWhenInUseAuthorization()
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
                // Notify that steps loaded
                NotificationCenter.default.post(name: NSNotification.Name("StepsLoaded"), object: nil)
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
        
        // Start from yesterday and go backwards
        var streakDays = 0
        var checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let group = DispatchGroup()
        var results: [Date: Bool] = [:]
        
        // Check up to 30 days back for streak
        for i in 0..<30 {
            let dayToCheck = calendar.date(byAdding: .day, value: -i, to: calendar.date(byAdding: .day, value: -1, to: today)!)!
            let dayStart = calendar.startOfDay(for: dayToCheck)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            group.enter()
            
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
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
            // Count consecutive days from yesterday
            var count = 0
            for i in 0..<30 {
                let dayToCheck = calendar.date(byAdding: .day, value: -i - 1, to: today)!
                let dayStart = calendar.startOfDay(for: dayToCheck)
                
                if results[dayStart] == true {
                    count += 1
                } else {
                    break
                }
            }
            self.streakCount = count
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
}
