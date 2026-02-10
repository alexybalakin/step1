//
//  Step1App.swift
//  Step1
//
//  Created by Alex Balakin on 1/18/26.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import BackgroundTasks
import HealthKit

@main
struct Step1App: App {

    init() {
        FirebaseApp.configure()
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    // MARK: - Background Task Registration

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "alex.Step1.stepSync", using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Self.handleBackgroundStepSync(task: refreshTask)
        }
    }

    static func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: "alex.Step1.stepSync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Background sync schedule error: \(error.localizedDescription)")
        }
    }

    private static func handleBackgroundStepSync(task: BGAppRefreshTask) {
        // Schedule the next sync
        scheduleBackgroundSync()

        guard let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous else {
            task.setTaskCompleted(success: true)
            return
        }

        let healthStore = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else {
            task.setTaskCompleted(success: true)
            return
        }

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        // Use HKStatisticsCollectionQuery to match Apple Health's values
        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startOfDay,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, error in
            let stats = results?.statistics(for: startOfDay)
            let steps: Int
            if let sum = stats?.sumQuantity() {
                steps = Int(sum.doubleValue(for: HKUnit.count()))
            } else {
                task.setTaskCompleted(success: false)
                return
            }
            let db = Firestore.firestore()
            let userId = currentUser.uid

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())

            let dailyData: [String: Any] = [
                "steps": steps,
                "updatedAt": FieldValue.serverTimestamp()
            ]

            // Update daily steps subcollection
            db.collection("leaderboard").document(userId).collection("daily").document(today).setData(dailyData, merge: true) { error in
                // Also update widget cache
                UserDefaults(suiteName: "group.alex.Step1")?.set(steps, forKey: "lastKnownSteps")
                UserDefaults(suiteName: "group.alex.Step1")?.set(Date().timeIntervalSince1970, forKey: "lastStepsUpdate")

                task.setTaskCompleted(success: error == nil)
            }

            // Also update main leaderboard document with name (so it shows in leaderboard)
            let displayName = currentUser.displayName ?? "User"
            let userData: [String: Any] = [
                "name": displayName,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            db.collection("leaderboard").document(userId).setData(userData, merge: true)
        }

        task.expirationHandler = {
            healthStore.stop(query)
        }

        healthStore.execute(query)
    }
}
