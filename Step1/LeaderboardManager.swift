//
//  LeaderboardManager.swift
//  Step1
//
//  Created by Alex Balakin on 1/19/26.
//

import SwiftUI

struct LeaderboardUser: Identifiable, Codable {
    let id: String
    var name: String
    var steps: Int
    var avatarLetter: String {
        String(name.prefix(1).uppercased())
    }
    
    init(id: String = UUID().uuidString, name: String, steps: Int) {
        self.id = id
        self.name = name
        self.steps = steps
    }
}

class LeaderboardManager: ObservableObject {
    @Published var users: [LeaderboardUser] = []
    @Published var currentUserID: String = "current_user"
    
    init() {
        loadUsers()
    }
    
    func generateDemoUsers() {
        let demoNames = [
            "Alice Johnson", "Bob Smith", "Charlie Brown", "Diana Prince",
            "Edward Norton", "Fiona Apple", "George Lucas", "Hannah Montana",
            "Ivan Petrov", "Julia Roberts", "Kevin Hart", "Laura Palmer",
            "Michael Jordan", "Nancy Drew", "Oscar Wilde", "Patricia Clark",
            "Quincy Jones", "Rachel Green", "Steve Jobs", "Tina Turner"
        ]
        
        var newUsers: [LeaderboardUser] = []
        
        for name in demoNames {
            let steps = Int.random(in: 2000...15000)
            newUsers.append(LeaderboardUser(name: name, steps: steps))
        }
        
        // Add current user
        let currentSteps = Int.random(in: 5000...12000)
        newUsers.append(LeaderboardUser(id: currentUserID, name: "You", steps: currentSteps))
        
        users = newUsers.sorted { $0.steps > $1.steps }
        saveUsers()
    }
    
    func deleteAllDemoUsers() {
        users = []
        saveUsers()
    }
    
    func updateCurrentUserSteps(_ steps: Int) {
        if let index = users.firstIndex(where: { $0.id == currentUserID }) {
            users[index].steps = steps
        } else {
            users.append(LeaderboardUser(id: currentUserID, name: "You", steps: steps))
        }
        users.sort { $0.steps > $1.steps }
        saveUsers()
    }
    
    func getCurrentUserRank() -> Int? {
        return users.firstIndex(where: { $0.id == currentUserID }).map { $0 + 1 }
    }
    
    private func saveUsers() {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: "leaderboard_users")
        }
    }
    
    private func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: "leaderboard_users"),
           let decoded = try? JSONDecoder().decode([LeaderboardUser].self, from: data) {
            users = decoded
        }
    }
}
