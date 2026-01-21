//
//  LeaderboardManager.swift
//  Step1
//
//  Created by Alex Balakin on 1/19/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct LeaderboardUser: Identifiable {
    let id: String
    var name: String
    var steps: Int
    var avatarLetter: String {
        String(name.prefix(1).uppercased())
    }
}

class LeaderboardManager: ObservableObject {
    @Published var users: [LeaderboardUser] = []
    @Published var isLoading = false
    @Published var selectedPeriod: Int = 0 // 0 = Day, 1 = Week, 2 = Month
    @Published var selectedDate: Date = Date()
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    var currentUserID: String {
        Auth.auth().currentUser?.uid ?? "anonymous"
    }
    
    init() {
        fetchLeaderboard()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Get date string for Firestore
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Get date range for period
    private func getDateRange() -> [String] {
        let calendar = Calendar.current
        var dates: [String] = []
        
        switch selectedPeriod {
        case 0: // Day
            dates = [dateString(from: selectedDate)]
        case 1: // Week
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: i, to: weekStart) {
                    dates.append(dateString(from: date))
                }
            }
        case 2: // Month
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
            let range = calendar.range(of: .day, in: .month, for: selectedDate)!
            for i in 0..<range.count {
                if let date = calendar.date(byAdding: .day, value: i, to: monthStart) {
                    dates.append(dateString(from: date))
                }
            }
        default:
            dates = [dateString(from: selectedDate)]
        }
        
        return dates
    }
    
    // MARK: - Fetch Leaderboard from Firestore
    func fetchLeaderboard() {
        isLoading = true
        
        listener?.remove()
        
        listener = db.collection("leaderboard")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching leaderboard: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.users = []
                    }
                    return
                }
                
                let dateRange = self.getDateRange()
                var leaderboardUsers: [LeaderboardUser] = []
                let group = DispatchGroup()
                
                for doc in documents {
                    let data = doc.data()
                    guard let name = data["name"] as? String else { continue }
                    
                    // Check if demo user
                    let isDemo = data["isDemo"] as? Bool ?? false
                    
                    if isDemo {
                        // For demo users, use their static steps
                        let steps = data["steps"] as? Int ?? 0
                        leaderboardUsers.append(LeaderboardUser(id: doc.documentID, name: name, steps: steps))
                    } else {
                        // For real users, fetch from daily subcollection
                        group.enter()
                        self.fetchStepsForUser(userId: doc.documentID, name: name, dates: dateRange) { user in
                            if let user = user {
                                leaderboardUsers.append(user)
                            }
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    self.users = leaderboardUsers.sorted { $0.steps > $1.steps }
                    self.isLoading = false
                }
            }
    }
    
    // MARK: - Fetch steps for a user from daily subcollection
    private func fetchStepsForUser(userId: String, name: String, dates: [String], completion: @escaping (LeaderboardUser?) -> Void) {
        // Handle empty dates array
        guard !dates.isEmpty else {
            completion(LeaderboardUser(id: userId, name: name, steps: 0))
            return
        }
        
        let dailyRef = db.collection("leaderboard").document(userId).collection("daily")
        
        // Firestore 'in' query limited to 10 items, so we may need to batch
        let chunks = stride(from: 0, to: dates.count, by: 10).map {
            Array(dates[$0..<min($0 + 10, dates.count)])
        }
        
        var totalSteps = 0
        let chunkGroup = DispatchGroup()
        
        for chunk in chunks {
            chunkGroup.enter()
            dailyRef.whereField(FieldPath.documentID(), in: chunk).getDocuments { snapshot, error in
                if let docs = snapshot?.documents {
                    for doc in docs {
                        if let steps = doc.data()["steps"] as? Int {
                            totalSteps += steps
                        }
                    }
                }
                chunkGroup.leave()
            }
        }
        
        chunkGroup.notify(queue: .main) {
            completion(LeaderboardUser(id: userId, name: name, steps: totalSteps))
        }
    }
    
    // MARK: - Update Current User Steps
    func updateCurrentUserSteps(_ steps: Int, name: String) {
        guard Auth.auth().currentUser != nil else {
            return
        }
        
        let today = dateString(from: Date())
        
        // Update main document with name
        let userData: [String: Any] = [
            "name": name,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("leaderboard").document(currentUserID).setData(userData, merge: true)
        
        // Update daily steps
        let dailyData: [String: Any] = [
            "steps": steps,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("leaderboard").document(currentUserID).collection("daily").document(today).setData(dailyData, merge: true) { error in
            if let error = error {
                print("Error updating daily steps: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Sync historical steps from HealthKit to Firestore
    func syncHistoricalSteps(steps: [String: Int], name: String) {
        guard Auth.auth().currentUser != nil else { return }
        
        // Update main document
        let userData: [String: Any] = [
            "name": name,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        db.collection("leaderboard").document(currentUserID).setData(userData, merge: true)
        
        // Update each day's steps
        for (date, stepCount) in steps {
            let dailyData: [String: Any] = [
                "steps": stepCount,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            db.collection("leaderboard").document(currentUserID).collection("daily").document(date).setData(dailyData, merge: true)
        }
    }
    
    // MARK: - Refresh leaderboard when period or date changes
    func refresh() {
        fetchLeaderboard()
    }
    
    // MARK: - Get Current User Rank
    func getCurrentUserRank() -> Int? {
        return users.firstIndex(where: { $0.id == currentUserID }).map { $0 + 1 }
    }
    
    // MARK: - Generate Demo Users (for testing)
    func generateDemoUsers() {
        let demoNames = [
            "Alice Johnson", "Bob Smith", "Charlie Brown", "Diana Prince",
            "Edward Norton", "Fiona Apple", "George Lucas", "Hannah Montana",
            "Ivan Petrov", "Julia Roberts", "Kevin Hart", "Laura Palmer",
            "Michael Jordan", "Nancy Drew", "Oscar Wilde", "Patricia Clark",
            "Quincy Jones", "Rachel Green", "Steve Rogers", "Tina Turner"
        ]
        
        let batch = db.batch()
        
        for name in demoNames {
            let steps = Int.random(in: 2000...15000)
            let docRef = db.collection("leaderboard").document(UUID().uuidString)
            batch.setData([
                "name": name,
                "steps": steps,
                "isDemo": true,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: docRef)
        }
        
        batch.commit { error in
            if let error = error {
                print("Error adding demo users: \(error.localizedDescription)")
            } else {
                print("Demo users added successfully")
            }
        }
    }
    
    // MARK: - Delete All Demo Users
    func deleteAllDemoUsers() {
        db.collection("leaderboard")
            .whereField("isDemo", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                let batch = self?.db.batch()
                for doc in documents {
                    batch?.deleteDocument(doc.reference)
                }
                
                batch?.commit { error in
                    if let error = error {
                        print("Error deleting demo users: \(error.localizedDescription)")
                    } else {
                        print("Demo users deleted successfully")
                    }
                }
            }
    }
    
    // MARK: - Delete Current User from Leaderboard
    func deleteCurrentUser() {
        db.collection("leaderboard").document(currentUserID).delete { error in
            if let error = error {
                print("Error deleting user: \(error.localizedDescription)")
            }
        }
    }
}
