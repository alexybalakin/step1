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
            if Calendar.current.isDateInToday(currentDate) {
                // If goal increased above current steps, reset celebration flag
                // so it can trigger again when goal is lowered back or steps catch up
                if dailyGoal > steps {
                    hasShownCelebrationToday = false
                    goalReached = false
                } else if steps >= dailyGoal {
                    // Goal lowered and now reached — trigger celebration
                    triggerCelebration()
                }
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
    private var isPedometerActive = false
    private var hasStartedLiveActivityToday = false
    private var pedometerStepsToday: Int = 0  // live pedometer count for today only

    // Callback for Firestore sync when steps update (set by ContentView)
    var onStepsUpdated: ((Int) -> Void)?

    /// Write steps + timestamp to App Group for widget, and force synchronize.
    private func cacheStepsForWidget(_ steps: Int) {
        let defaults = UserDefaults(suiteName: "group.alex.Step1")
        defaults?.set(steps, forKey: "lastKnownSteps")
        defaults?.set(Date().timeIntervalSince1970, forKey: "lastStepsUpdate")
        defaults?.synchronize()
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Set initial value from saved flag, then verify async
        healthKitConnected = UserDefaults.standard.bool(forKey: "healthKitAuthorizationGranted")
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
        // Load cached stats so they show even without HK
        streakCount = UserDefaults.standard.integer(forKey: "cachedStreakCount")
        maxStreak = UserDefaults.standard.integer(forKey: "cachedMaxStreak")
        let cachedBest = UserDefaults.standard.integer(forKey: "cachedBestDaySteps")
        if cachedBest > 0 {
            bestDaySteps = cachedBest
            let cachedBestTime = UserDefaults.standard.double(forKey: "cachedBestDayDate")
            if cachedBestTime > 0 {
                bestDayDate = Date(timeIntervalSince1970: cachedBestTime)
            }
        }
        let cachedSteps = UserDefaults.standard.integer(forKey: "cachedTodaySteps")
        if cachedSteps > 0 { steps = cachedSteps; goalReached = steps >= dailyGoal }
        let cachedDist = UserDefaults.standard.double(forKey: "cachedDistance")
        if cachedDist > 0 { distance = cachedDist }
        let cachedDur = UserDefaults.standard.integer(forKey: "cachedDuration")
        if cachedDur > 0 { duration = cachedDur }
        if let cachedHourly = UserDefaults.standard.array(forKey: "cachedHourlyStepsToday") as? [Int], cachedHourly.count == 24 {
            hourlyStepsToday = cachedHourly
        }
        if let cachedHourlyY = UserDefaults.standard.array(forKey: "cachedHourlyStepsYesterday") as? [Int], cachedHourlyY.count == 24 {
            hourlyStepsYesterday = cachedHourlyY
        }
        // Verify actual HK access (async — updates healthKitConnected)
        verifyHealthKitAccess()
    }
    
    // FIX #3: Helper to trigger celebration
    func triggerCelebration() {
        guard !hasShownCelebrationToday else { return }
        hasShownCelebrationToday = true
        UserDefaults.standard.set(Date(), forKey: "lastCelebrationDate")
        shouldShowCelebration = true
    }
    
    // Unified celebration check — call on launch, foreground, and after data loads
    func checkAndTriggerCelebration() {
        guard Calendar.current.isDateInToday(currentDate) else { return }
        guard !hasShownCelebrationToday else { return }
        if steps >= dailyGoal {
            triggerCelebration()
        }
    }
    
    func saveDailyGoal() {
        UserDefaults.standard.set(dailyGoal, forKey: "dailyStepGoal")
        // Save to App Group for widget
        UserDefaults(suiteName: "group.alex.Step1")?.set(dailyGoal, forKey: "dailyStepGoal")
        // Save today's goal to history so streak calculation uses the correct goal for each day
        saveTodayGoalToHistory()
        // Reload widget
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadDailyGoal() {
        let saved = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        if saved > 0 {
            dailyGoal = saved
        }
        // Ensure today's goal is saved to history
        saveTodayGoalToHistory()
    }

    // MARK: - Goal History (for streak calculation)
    // Stores the active goal for each day so that changing the goal doesn't retroactively affect streak

    private func saveTodayGoalToHistory() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        var history = UserDefaults.standard.dictionary(forKey: "dailyGoalHistory") as? [String: Int] ?? [:]
        history[todayKey] = dailyGoal
        UserDefaults.standard.set(history, forKey: "dailyGoalHistory")
    }

    func goalForDate(_ date: Date) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)

        let history = UserDefaults.standard.dictionary(forKey: "dailyGoalHistory") as? [String: Int] ?? [:]
        // If we have a historical goal for that day, use it; otherwise use current goal
        return history[key] ?? dailyGoal
    }
    
    // MARK: - Separate authorization methods for onboarding

    func requestHealthKitAuthorization(completion: ((Bool) -> Void)? = nil) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let exerciseTimeType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!

        let typesToRead: Set = [stepType, distanceType, activeEnergyType, exerciseTimeType]
        // Request write for stepCount so we can check authorizationStatus(for:) reliably
        let typesToWrite: Set<HKSampleType> = [stepType]

        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            if success {
                // Mark as granted — for read-only types iOS doesn't expose status
                UserDefaults.standard.set(true, forKey: "healthKitAuthorizationGranted")
                UserDefaults.standard.set(true, forKey: "healthKitWasConnectedBefore")
                DispatchQueue.main.async {
                    self?.healthKitConnected = true
                }
                self?.loadDataForCurrentDate()
                self?.enableBackgroundDelivery()
                self?.startObservingSteps()
            }
            DispatchQueue.main.async {
                completion?(success)
            }
        }
    }

    /// Legacy method — calls all permissions at once (used when onboarding already completed)
    func requestAuthorization() {
        requestHealthKitAuthorization()
        locationManager.requestWhenInUseAuthorization()
        requestMotionPermission()
    }

    /// Check if HealthKit authorization was already granted
    /// Note: For read-only types, iOS doesn't expose the exact auth status for privacy.
    /// We track it ourselves via UserDefaults after a successful requestAuthorization.
    @Published var healthKitConnected: Bool = false

    func isHealthKitAuthorized() -> Bool {
        return healthKitConnected
    }

    /// Verify actual HK access by checking write authorization status for stepCount.
    /// For write types, authorizationStatus(for:) returns the real status (.sharingAuthorized, .sharingDenied, .notDetermined).
    /// This is the only reliable way to detect revoked permissions on iOS.
    /// NOTE: authorizationStatus(for:) is synchronous, so we update healthKitConnected immediately
    /// to avoid race conditions with loadDataForCurrentDate().
    func verifyHealthKitAccess() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthKitConnected = false
            return
        }

        let savedFlag = UserDefaults.standard.bool(forKey: "healthKitAuthorizationGranted")
        guard savedFlag else {
            healthKitConnected = false
            return
        }

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let status = healthStore.authorizationStatus(for: stepType)

        switch status {
        case .sharingAuthorized:
            healthKitConnected = true
        case .sharingDenied:
            // User explicitly denied — HK is disconnected
            healthKitConnected = false
            UserDefaults.standard.set(false, forKey: "healthKitAuthorizationGranted")
        case .notDetermined:
            // Never asked or permission was reset — treat as disconnected
            healthKitConnected = false
            UserDefaults.standard.set(false, forKey: "healthKitAuthorizationGranted")
        @unknown default:
            healthKitConnected = false
        }
    }
    
    func requestMotionPermission(completion: ((Bool) -> Void)? = nil) {
        guard CMPedometer.isStepCountingAvailable() else {
            print("Step counting not available")
            completion?(false)
            return
        }

        // This triggers the Motion & Fitness permission dialog
        pedometer.queryPedometerData(from: Date().addingTimeInterval(-86400), to: Date()) { [weak self] data, error in
            if let error = error {
                print("Pedometer error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion?(false) }
            } else {
                print("Motion & Fitness permission granted")
                DispatchQueue.main.async {
                    completion?(true)
                    self?.startPedometerUpdates()
                }
            }
        }
    }

    // MARK: - CMPedometer Real-Time Step Tracking

    func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        guard !isPedometerActive else { return }

        // Restore cached pedometer steps for today
        let savedDate = UserDefaults.standard.string(forKey: "pedometerStepsDate") ?? ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        if savedDate == todayKey {
            pedometerStepsToday = UserDefaults.standard.integer(forKey: "pedometerStepsCount")
        } else {
            pedometerStepsToday = 0
        }

        let startOfToday = Calendar.current.startOfDay(for: Date())
        isPedometerActive = true

        pedometer.startUpdates(from: startOfToday) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }

            let pedometerSteps = data.numberOfSteps.intValue

            DispatchQueue.main.async {
                self.pedometerStepsToday = pedometerSteps

                // Persist pedometer steps for today
                UserDefaults.standard.set(pedometerSteps, forKey: "pedometerStepsCount")
                UserDefaults.standard.set(todayKey, forKey: "pedometerStepsDate")

                // Use max of pedometer and current steps (HK may have reported more)
                let newSteps = max(pedometerSteps, self.steps)
                guard newSteps != self.steps else { return }

                let wasGoalReached = self.goalReached
                self.steps = newSteps
                self.goalReached = newSteps >= self.dailyGoal

                // Check celebration
                if self.goalReached && !wasGoalReached {
                    self.triggerCelebration()
                }

                // Cache for widget (synchronize ensures widget reads fresh data)
                self.cacheStepsForWidget(newSteps)
                WidgetCenter.shared.reloadAllTimelines()

                // Start Live Activity on first step detection, then keep updating
                if #available(iOS 16.1, *) {
                    if !self.hasStartedLiveActivityToday {
                        self.hasStartedLiveActivityToday = true
                        self.startLiveActivity()
                    } else {
                        self.updateLiveActivity()
                    }
                }

                // Notify for Firestore sync
                self.onStepsUpdated?(newSteps)
            }
        }
    }

    func stopPedometerUpdates() {
        pedometer.stopUpdates()
        isPedometerActive = false
    }

    func restartPedometerForNewDay() {
        stopPedometerUpdates()
        pedometerStepsToday = 0
        hasStartedLiveActivityToday = false
        // Reset widget cache for new day
        cacheStepsForWidget(0)
        WidgetCenter.shared.reloadAllTimelines()
        // End previous day's Live Activity
        if #available(iOS 16.1, *) {
            endLiveActivity()
        }
        startPedometerUpdates()
    }
    
    // MARK: - FIX #5: Enable background delivery for widget updates
    func enableBackgroundDeliveryPublic() { enableBackgroundDelivery() }
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
    
    func startObservingStepsPublic() { startObservingSteps() }
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
                guard let self = self else { return }
                self.fetchStepsForDate(self.currentDate)
                // Also fetch today if viewing a different date
                let today = Date()
                if !Calendar.current.isDate(self.currentDate, inSameDayAs: today) {
                    self.fetchStepsForToday()
                }
            }
            
            // Reload widget timeline
            WidgetCenter.shared.reloadAllTimelines()
            
            completionHandler()
        }
        
        stepObserverQuery = query
        healthStore.execute(query)
    }
    
    func loadDataForCurrentDate() {
        let calendar = Calendar.current

        // For today: show cached pedometer steps immediately
        if calendar.isDateInToday(currentDate) && pedometerStepsToday > 0 {
            steps = pedometerStepsToday
            goalReached = steps >= dailyGoal
        }

        // If HK is not connected, don't run HK queries — keep showing cached data
        guard healthKitConnected else { return }

        // Check if sync is enabled
        let syncEnabled = UserDefaults.standard.object(forKey: "healthKitSyncEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "healthKitSyncEnabled")
        guard syncEnabled else { return }

        fetchStepsForDate(currentDate)
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
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

        // Start from 11 months ago
        var startComponents = calendar.dateComponents([.year, .month], from: now)
        startComponents.month! -= 11
        guard let yearStart = calendar.date(from: startComponents) else { return }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!

        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: yearStart,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            var monthTotals: [Int: (total: Int, days: Int)] = [:]

            results.enumerateStatistics(from: yearStart, to: tomorrow) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                guard dayStart <= calendar.startOfDay(for: now) else { return }

                let monthComp = calendar.dateComponents([.year, .month], from: dayStart)
                let key = monthComp.year! * 100 + monthComp.month!

                let steps: Int
                if let sum = stats.sumQuantity() {
                    steps = Int(sum.doubleValue(for: HKUnit.count()))
                } else {
                    steps = 0
                }

                if var existing = monthTotals[key] {
                    existing.total += steps
                    existing.days += 1
                    monthTotals[key] = existing
                } else {
                    monthTotals[key] = (total: steps, days: 1)
                }
            }

            // Map to 12-element arrays
            var tempProgress: [Double] = Array(repeating: 0.0, count: 12)
            var tempGoalMet: [Bool] = Array(repeating: false, count: 12)

            for monthOffset in 0..<12 {
                var components = calendar.dateComponents([.year, .month], from: now)
                components.month! -= (11 - monthOffset)
                if let date = calendar.date(from: components) {
                    let comp = calendar.dateComponents([.year, .month], from: date)
                    let key = comp.year! * 100 + comp.month!
                    if let data = monthTotals[key], data.days > 0 {
                        let avgSteps = data.total / data.days
                        let progress = Double(avgSteps) / Double(self.dailyGoal)
                        tempProgress[monthOffset] = progress
                        tempGoalMet[monthOffset] = progress >= 1.0
                    }
                }
            }

            DispatchQueue.main.async {
                self.yearProgress = tempProgress
                self.yearGoalMet = tempGoalMet
            }
        }

        healthStore.execute(query)
    }
    
    // MARK: - Fetch Quarter Progress (12 weeks)
    func fetchQuarterProgress() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // 11 weeks ago start
        guard let elevenWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -11, to: now),
              let quarterStart = calendar.dateInterval(of: .weekOfYear, for: elevenWeeksAgo)?.start else { return }

        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: quarterStart,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            // Build week boundaries
            var weekBuckets: [(start: Date, end: Date)] = []
            for weekOffset in 0..<12 {
                guard let weekDate = calendar.date(byAdding: .weekOfYear, value: -(11 - weekOffset), to: now),
                      let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: weekDate)?.start else { continue }
                let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
                weekBuckets.append((start: startOfWeek, end: endOfWeek))
            }

            var weekTotals: [(total: Int, days: Int)] = Array(repeating: (0, 0), count: 12)

            results.enumerateStatistics(from: quarterStart, to: tomorrow) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                guard dayStart <= today else { return }

                for (idx, bucket) in weekBuckets.enumerated() {
                    if dayStart >= bucket.start && dayStart < bucket.end {
                        let steps: Int
                        if let sum = stats.sumQuantity() {
                            steps = Int(sum.doubleValue(for: HKUnit.count()))
                        } else {
                            steps = 0
                        }
                        weekTotals[idx].total += steps
                        weekTotals[idx].days += 1
                        break
                    }
                }
            }

            var tempProgress: [Double] = Array(repeating: 0.0, count: 12)
            var tempGoalMet: [Bool] = Array(repeating: false, count: 12)

            for i in 0..<12 {
                if weekTotals[i].days > 0 {
                    let avgSteps = weekTotals[i].total / weekTotals[i].days
                    let progress = Double(avgSteps) / Double(self.dailyGoal)
                    tempProgress[i] = progress
                    tempGoalMet[i] = progress >= 1.0
                }
            }

            DispatchQueue.main.async {
                self.quarterProgress = tempProgress
                self.quarterGoalMet = tempGoalMet
            }
        }

        healthStore.execute(query)
    }
    
    func fetchStepsForDate(_ date: Date) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Use HKStatisticsCollectionQuery to match Apple Health's day-boundary splitting logic.
        // This correctly handles samples that span midnight by proportionally attributing steps.
        let interval = DateComponents(day: 1)
        let anchorDate = calendar.startOfDay(for: date)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: anchorDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
                DispatchQueue.main.async {
                    // If HK fails, still try to show pedometer data for today
                    if calendar.isDateInToday(date) && self.pedometerStepsToday > 0 {
                        self.steps = self.pedometerStepsToday
                        self.goalReached = self.steps >= self.dailyGoal
                    } else {
                        self.steps = 0
                        self.goalReached = false
                    }
                }
                return
            }

            // Get the statistics for the specific day we're interested in
            let stats = results.statistics(for: startOfDay)
            let hkSteps: Int
            if let sum = stats?.sumQuantity() {
                hkSteps = Int(sum.doubleValue(for: HKUnit.count()))
            } else {
                hkSteps = 0
            }

            DispatchQueue.main.async {
                let wasGoalReached = self.goalReached

                // For today: use max of HealthKit and pedometer (pedometer is more real-time)
                if calendar.isDateInToday(date) {
                    self.steps = max(hkSteps, self.pedometerStepsToday)
                } else {
                    self.steps = hkSteps
                }
                self.goalReached = self.steps >= self.dailyGoal

                // Show celebration when goal is newly reached
                if calendar.isDateInToday(date) && self.goalReached && !wasGoalReached {
                    self.triggerCelebration()
                }

                // Cache current steps for widget and offline display
                if calendar.isDateInToday(date) {
                    self.cacheStepsForWidget(self.steps)
                    UserDefaults.standard.set(self.steps, forKey: "cachedTodaySteps")
                    WidgetCenter.shared.reloadAllTimelines()

                    // Update Live Activity
                    if #available(iOS 16.1, *) {
                        self.updateLiveActivity()
                    }

                    // Notify for Firestore sync
                    self.onStepsUpdated?(self.steps)
                }
            }
        }

        healthStore.execute(query)
    }

    /// Fetch today's steps silently (for cache/Firestore sync when viewing a past date)
    private func fetchStepsForToday() {
        fetchStepsForSingleDay(Date()) { [weak self] todaySteps in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Update cache for widget (only if we got real data)
                if todaySteps > 0 {
                    self.cacheStepsForWidget(todaySteps)
                }
                // Sync to Firestore
                self.onStepsUpdated?(todaySteps)
            }
        }
    }

    /// Reusable helper: fetches steps for a single day using HKStatisticsCollectionQuery
    /// which properly handles samples spanning midnight (matches Apple Health values).
    func fetchStepsForSingleDay(_ date: Date, completion: @escaping (Int) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

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
            let steps: Int
            if let sum = stats?.sumQuantity() {
                steps = Int(sum.doubleValue(for: HKUnit.count()))
            } else {
                steps = 0
            }
            completion(steps)
        }

        healthStore.execute(query)
    }

    func fetchDistanceForDate(_ date: Date, isYesterday: Bool = false) {
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [.strictStartDate, .strictEndDate])
        
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
                    UserDefaults.standard.set(dist, forKey: "cachedDistance")
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
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [.strictStartDate, .strictEndDate])
        
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
                    UserDefaults.standard.set(activeMinutes, forKey: "cachedDuration")
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
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        let today = Date()
        let todayStart = calendar.startOfDay(for: today)

        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: weekStart,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            var tempResults: [(streak: Bool, progress: Double)] = Array(repeating: (false, 0.0), count: 7)

            results.enumerateStatistics(from: weekStart, to: weekEnd) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                guard dayStart <= todayStart else { return }

                if let daysDiff = calendar.dateComponents([.day], from: weekStart, to: dayStart).day,
                   daysDiff >= 0 && daysDiff < 7 {
                    let steps: Int
                    if let sum = stats.sumQuantity() {
                        steps = Int(sum.doubleValue(for: HKUnit.count()))
                    } else {
                        steps = 0
                    }
                    let progress = Double(steps) / Double(self.dailyGoal)
                    tempResults[daysDiff] = (steps >= self.dailyGoal, progress)
                }
            }

            DispatchQueue.main.async {
                self.weekStreak = tempResults.map { $0.streak }
                self.weekProgress = tempResults.map { $0.progress }
                self.fetchLast7DaysProgress()
            }
        }

        healthStore.execute(query)
    }
    
    // MARK: - Last 7 days progress (today = rightmost)
    @Published var last7DaysProgress: [Double] = Array(repeating: 0.0, count: 7)
    @Published var last7DaysLabels: [String] = Array(repeating: "", count: 7)
    @Published var last7DaysGoalMet: [Bool] = Array(repeating: false, count: 7)
    
    func fetchLast7DaysProgress() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let dayAbbrs = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

        var tempProgress: [Double] = Array(repeating: 0.0, count: 7)
        var tempLabels: [String] = Array(repeating: "", count: 7)
        var tempGoalMet: [Bool] = Array(repeating: false, count: 7)

        // Build labels
        for i in 0..<7 {
            let dayStart = calendar.date(byAdding: .day, value: -(6 - i), to: today)!
            let weekday = calendar.component(.weekday, from: dayStart)
            tempLabels[i] = dayAbbrs[weekday - 1]
        }

        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: sixDaysAgo,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            results.enumerateStatistics(from: sixDaysAgo, to: tomorrow) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                if let daysDiff = calendar.dateComponents([.day], from: sixDaysAgo, to: dayStart).day,
                   daysDiff >= 0 && daysDiff < 7 {
                    let steps: Int
                    if let sum = stats.sumQuantity() {
                        steps = Int(sum.doubleValue(for: HKUnit.count()))
                    } else {
                        steps = 0
                    }
                    tempProgress[daysDiff] = Double(steps) / Double(self.dailyGoal)
                    tempGoalMet[daysDiff] = steps >= self.dailyGoal
                }
            }

            DispatchQueue.main.async {
                self.last7DaysProgress = tempProgress
                self.last7DaysLabels = tempLabels
                self.last7DaysGoalMet = tempGoalMet
            }
        }

        healthStore.execute(query)
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

        let today = calendar.startOfDay(for: Date())
        let currentWeekday = calendar.component(.weekday, from: today)
        let firstDay = calendar.firstWeekday
        var daysFromStart = currentWeekday - firstDay
        if daysFromStart < 0 { daysFromStart += 7 }
        let thisWeekStart = calendar.date(byAdding: .day, value: -daysFromStart, to: today)!

        let weekStart = calendar.date(byAdding: .day, value: offset * 7, to: thisWeekStart)!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        DispatchQueue.main.async {
            self.weekSummaryStartDate = weekStart
            self.weekSummaryEndDate = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        }

        let todayStart = calendar.startOfDay(for: Date())
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: weekStart,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            var tempSteps: [Int] = Array(repeating: 0, count: 7)
            var tempGoalMet: [Bool] = Array(repeating: false, count: 7)

            results.enumerateStatistics(from: weekStart, to: weekEnd) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                guard dayStart <= todayStart else { return }

                if let dayIdx = calendar.dateComponents([.day], from: weekStart, to: dayStart).day,
                   dayIdx >= 0 && dayIdx < 7 {
                    let steps: Int
                    if let sum = stats.sumQuantity() {
                        steps = Int(sum.doubleValue(for: HKUnit.count()))
                    } else {
                        steps = 0
                    }
                    tempSteps[dayIdx] = steps
                    tempGoalMet[dayIdx] = steps >= self.dailyGoal
                }
            }

            DispatchQueue.main.async {
                self.weekSummaryDailySteps = tempSteps
                self.weekSummaryDailyGoalMet = tempGoalMet
                let total = tempSteps.reduce(0, +)
                self.weekSummaryTotal = total
                let activeDays = tempSteps.filter { $0 > 0 }.count
                self.weekSummaryAvg = activeDays > 0 ? total / activeDays : 0

                let totalSteps = Double(total)
                self.weekSummaryTotalDistance = totalSteps * 0.00075
                self.weekSummaryTotalDuration = Int((totalSteps * 0.00075 / 5.0) * 3600.0)
                self.weekSummaryTotalCalories = totalSteps * 0.045

                self.fetchPrevWeekAvg(prevWeekStart: calendar.date(byAdding: .day, value: -7, to: weekStart)!)
            }
        }

        healthStore.execute(query)
    }
    
    private func fetchPrevWeekAvg(prevWeekStart: Date) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = appCalendar
        let todayStart = calendar.startOfDay(for: Date())
        let prevWeekEnd = calendar.date(byAdding: .day, value: 7, to: prevWeekStart)!
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: prevWeekStart,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            var tempSteps: [Int] = Array(repeating: 0, count: 7)

            results.enumerateStatistics(from: prevWeekStart, to: prevWeekEnd) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                guard dayStart <= todayStart else { return }

                if let dayIdx = calendar.dateComponents([.day], from: prevWeekStart, to: dayStart).day,
                   dayIdx >= 0 && dayIdx < 7 {
                    if let sum = stats.sumQuantity() {
                        tempSteps[dayIdx] = Int(sum.doubleValue(for: HKUnit.count()))
                    }
                }
            }

            DispatchQueue.main.async {
                let total = tempSteps.reduce(0, +)
                let activeDays = tempSteps.filter { $0 > 0 }.count
                self.weekSummaryPrevAvg = activeDays > 0 ? total / activeDays : 0
            }
        }

        healthStore.execute(query)
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

        let components = calendar.dateComponents([.year, .month], from: today)
        let thisMonth1st = calendar.date(from: components)!
        let targetMonth1st = calendar.date(byAdding: .month, value: offset, to: thisMonth1st)!
        let nextMonth1st = calendar.date(byAdding: .month, value: 1, to: targetMonth1st)!
        let daysInMonth = calendar.range(of: .day, in: .month, for: targetMonth1st)!.count

        DispatchQueue.main.async {
            self.monthSummaryMonth = targetMonth1st
        }

        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: targetMonth1st,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            var tempSteps: [Int] = Array(repeating: 0, count: daysInMonth)
            var tempGoalMet: [Bool] = Array(repeating: false, count: daysInMonth)

            results.enumerateStatistics(from: targetMonth1st, to: nextMonth1st) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                guard dayStart <= today else { return }

                if let dayIdx = calendar.dateComponents([.day], from: targetMonth1st, to: dayStart).day,
                   dayIdx >= 0 && dayIdx < daysInMonth {
                    let steps: Int
                    if let sum = stats.sumQuantity() {
                        steps = Int(sum.doubleValue(for: HKUnit.count()))
                    } else {
                        steps = 0
                    }
                    tempSteps[dayIdx] = steps
                    tempGoalMet[dayIdx] = steps >= self.dailyGoal
                }
            }

            DispatchQueue.main.async {
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

                self.fetchPrevMonthAvg(prevMonth1st: calendar.date(byAdding: .month, value: -1, to: targetMonth1st)!)
            }
        }

        healthStore.execute(query)
    }

    private func fetchPrevMonthAvg(prevMonth1st: Date) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let nextMonth1st = calendar.date(byAdding: .month, value: 1, to: prevMonth1st)!
        let daysInMonth = calendar.range(of: .day, in: .month, for: prevMonth1st)!.count

        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: prevMonth1st,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            var tempSteps: [Int] = Array(repeating: 0, count: daysInMonth)

            results.enumerateStatistics(from: prevMonth1st, to: nextMonth1st) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                guard dayStart <= todayStart else { return }

                if let dayIdx = calendar.dateComponents([.day], from: prevMonth1st, to: dayStart).day,
                   dayIdx >= 0 && dayIdx < daysInMonth {
                    if let sum = stats.sumQuantity() {
                        tempSteps[dayIdx] = Int(sum.doubleValue(for: HKUnit.count()))
                    }
                }
            }

            DispatchQueue.main.async {
                let total = tempSteps.reduce(0, +)
                let activeDays = tempSteps.filter { $0 > 0 }.count
                self.monthSummaryPrevAvg = activeDays > 0 ? total / activeDays : 0
            }
        }

        healthStore.execute(query)
    }
    
    func calculateGlobalStreak() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysToCheck = 365
        let startDate = calendar.date(byAdding: .day, value: -daysToCheck, to: today)!

        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            var dayGoalMet: [Date: Bool] = [:]

            results.enumerateStatistics(from: startDate, to: today) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                let steps: Int
                if let sum = stats.sumQuantity() {
                    steps = Int(sum.doubleValue(for: HKUnit.count()))
                } else {
                    steps = 0
                }
                // Use the goal that was active on that specific day
                let goalForThatDay = self.goalForDate(dayStart)
                dayGoalMet[dayStart] = steps >= goalForThatDay
            }

            DispatchQueue.main.async {
                // Count current streak (consecutive days from yesterday backwards)
                var currentCount = 0
                for i in 0..<daysToCheck {
                    let dayToCheck = calendar.date(byAdding: .day, value: -i - 1, to: today)!
                    let dayStart = calendar.startOfDay(for: dayToCheck)

                    if dayGoalMet[dayStart] == true {
                        currentCount += 1
                    } else {
                        break
                    }
                }
                self.streakCount = currentCount
                UserDefaults.standard.set(currentCount, forKey: "cachedStreakCount")

                // Calculate max streak
                var maxCount = 0
                var tempCount = 0
                for i in 0..<daysToCheck {
                    let dayToCheck = calendar.date(byAdding: .day, value: -i - 1, to: today)!
                    let dayStart = calendar.startOfDay(for: dayToCheck)

                    if dayGoalMet[dayStart] == true {
                        tempCount += 1
                        maxCount = max(maxCount, tempCount)
                    } else {
                        tempCount = 0
                    }
                }
                self.maxStreak = max(maxCount, currentCount)
                UserDefaults.standard.set(self.maxStreak, forKey: "cachedMaxStreak")
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fetch Best Day (highest step count in last 365 days)
    func fetchBestDay() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let startDate = calendar.date(byAdding: .day, value: -365, to: today)!

        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            var bestSteps = 0
            var bestDate: Date? = nil

            results.enumerateStatistics(from: startDate, to: tomorrow) { stats, _ in
                if let sum = stats.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    if steps > bestSteps {
                        bestSteps = steps
                        bestDate = stats.startDate
                    }
                }
            }

            DispatchQueue.main.async {
                if bestSteps > 0 {
                    self.bestDaySteps = bestSteps
                    self.bestDayDate = bestDate
                    // Cache for offline access
                    UserDefaults.standard.set(bestSteps, forKey: "cachedBestDaySteps")
                    if let d = bestDate {
                        UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "cachedBestDayDate")
                    }
                }
            }
        }

        healthStore.execute(query)
    }
    
    // MARK: - Fetch Hourly Steps for Day Progress Chart
    /// Fetches per-hour step counts using individual HKQuantitySample records.
    /// Each sample's steps are attributed to the hour when the sample STARTED.
    /// This avoids the HKStatisticsCollectionQuery issue where long-running samples
    /// (e.g. Apple Watch overnight) get proportionally distributed across hours,
    /// creating phantom step counts during hours when no actual walking occurred.
    func fetchHourlySteps(for date: Date, isToday: Bool) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        // Fetch individual step samples for this day
        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart,
            end: dayEnd,
            options: [.strictStartDate]
        )

        let query = HKSampleQuery(
            sampleType: stepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, samples, _ in
            guard let self = self else { return }

            var hourlyResults = Array(repeating: 0, count: 24)

            if let quantitySamples = samples as? [HKQuantitySample] {
                for sample in quantitySamples {
                    let sampleStart = sample.startDate
                    let sampleEnd = sample.endDate
                    let steps = Int(sample.quantity.doubleValue(for: HKUnit.count()))

                    // Calculate sample duration in seconds
                    let sampleDuration = sampleEnd.timeIntervalSince(sampleStart)

                    if sampleDuration <= 3600 {
                        // Short sample (≤1 hour): attribute all steps to the start hour
                        let hour = calendar.component(.hour, from: sampleStart)
                        if hour >= 0 && hour < 24 {
                            hourlyResults[hour] += steps
                        }
                    } else {
                        // Long sample (>1 hour): distribute proportionally across hours
                        // but only for hours within this day
                        guard sampleDuration > 0 else { continue }
                        let stepsPerSecond = Double(steps) / sampleDuration

                        // Clamp to day boundaries
                        let effectiveStart = max(sampleStart, dayStart)
                        let effectiveEnd = min(sampleEnd, dayEnd)

                        var hourCursor = effectiveStart
                        while hourCursor < effectiveEnd {
                            let hour = calendar.component(.hour, from: hourCursor)
                            // Next hour boundary
                            var nextHourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: hourCursor)
                            nextHourComponents.hour! += 1
                            let nextHour = min(calendar.date(from: nextHourComponents) ?? effectiveEnd, effectiveEnd)

                            let secondsInThisHour = nextHour.timeIntervalSince(hourCursor)
                            let stepsInThisHour = Int(stepsPerSecond * secondsInThisHour)

                            if hour >= 0 && hour < 24 {
                                hourlyResults[hour] += stepsInThisHour
                            }
                            hourCursor = nextHour
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                if isToday {
                    self.hourlyStepsToday = hourlyResults
                    UserDefaults.standard.set(hourlyResults, forKey: "cachedHourlyStepsToday")
                } else {
                    self.hourlyStepsYesterday = hourlyResults
                    UserDefaults.standard.set(hourlyResults, forKey: "cachedHourlyStepsYesterday")
                }
            }
        }

        healthStore.execute(query)
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
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return }

        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let endDate = min(monthInterval.end, tomorrow)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let dayInterval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: monthInterval.start,
            intervalComponents: dayInterval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let results = results else { return }

            var tempCache: [String: Double] = [:]

            results.enumerateStatistics(from: monthInterval.start, to: endDate) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                guard dayStart <= today else { return }

                let dateKey = formatter.string(from: dayStart)
                if let sum = stats.sumQuantity() {
                    let steps = sum.doubleValue(for: HKUnit.count())
                    let progress = self.dailyGoal > 0 ? steps / Double(self.dailyGoal) : 0
                    tempCache[dateKey] = progress
                } else {
                    tempCache[dateKey] = 0
                }
            }

            DispatchQueue.main.async {
                self.dayProgressCache.merge(tempCache) { _, new in new }
            }
        }

        healthStore.execute(query)
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
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let startDate = calendar.date(byAdding: .day, value: -days, to: today)!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results = results else {
                DispatchQueue.main.async { completion([:]) }
                return
            }

            var stepsHistory: [String: Int] = [:]

            results.enumerateStatistics(from: startDate, to: tomorrow) { stats, _ in
                let dayStart = calendar.startOfDay(for: stats.startDate)
                let dateKey = formatter.string(from: dayStart)
                if let sum = stats.sumQuantity() {
                    stepsHistory[dateKey] = Int(sum.doubleValue(for: HKUnit.count()))
                }
            }

            DispatchQueue.main.async {
                completion(stepsHistory)
            }
        }

        healthStore.execute(query)
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
