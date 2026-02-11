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
        loadFriends()
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
    func getDateRange() -> [String] {
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
                    var name = data["name"] as? String ?? ""
                    
                    // FIX #2: если имя пустое, присваиваем "User N"
                    if name.trimmingCharacters(in: .whitespaces).isEmpty {
                        name = "User \(doc.documentID.prefix(4))"
                    }
                    
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
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        
        // FIX #9: Don't sync anonymous users to leaderboard
        if currentUser.isAnonymous {
            return
        }
        
        let today = dateString(from: Date())
        
        // FIX #2: Проверяем, не пустое ли имя
        var finalName = name
        if finalName.trimmingCharacters(in: .whitespaces).isEmpty {
            finalName = generateUniqueUserName()
        }
        
        // Update main document with name
        let userData: [String: Any] = [
            "name": finalName,
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
    
    // MARK: - FIX #2: Generate unique "User N" name
    func generateUniqueUserName() -> String {
        // Собираем существующие номера User N
        let existingNumbers = users.compactMap { user -> Int? in
            let name = user.name
            if name.hasPrefix("User ") {
                let numberPart = name.dropFirst(5)
                return Int(numberPart)
            }
            return nil
        }
        
        // Находим следующий свободный номер
        var nextNumber = 1
        while existingNumbers.contains(nextNumber) {
            nextNumber += 1
        }
        
        return "User \(nextNumber)"
    }
    
    // MARK: - FIX #2: Assign names to users with empty names
    func assignNamesToEmptyUsers() {
        db.collection("leaderboard").getDocuments { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else { return }
            
            var usedNumbers: Set<Int> = []
            
            // First pass: collect existing User N numbers
            for doc in documents {
                if let name = doc.data()["name"] as? String, name.hasPrefix("User ") {
                    if let num = Int(name.dropFirst(5)) {
                        usedNumbers.insert(num)
                    }
                }
            }
            
            // Second pass: assign numbers to empty names
            for doc in documents {
                let name = doc.data()["name"] as? String ?? ""
                if name.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Find next available number
                    var nextNumber = 1
                    while usedNumbers.contains(nextNumber) {
                        nextNumber += 1
                    }
                    usedNumbers.insert(nextNumber)
                    
                    let newName = "User \(nextNumber)"
                    self.db.collection("leaderboard").document(doc.documentID).updateData([
                        "name": newName
                    ])
                }
            }
        }
    }
    
    // MARK: - Sync historical steps from HealthKit to Firestore
    func syncHistoricalSteps(steps: [String: Int], name: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // FIX #9: Don't sync anonymous users
        if currentUser.isAnonymous { return }
        
        // FIX #2: Проверяем имя
        var finalName = name
        if finalName.trimmingCharacters(in: .whitespaces).isEmpty {
            finalName = generateUniqueUserName()
        }
        
        // Update main document
        let userData: [String: Any] = [
            "name": finalName,
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
    
    // MARK: - Friends Management
    @Published var friends: Set<String> = []
    @Published var showFriendsOnly: Bool = false
    
    var filteredUsers: [LeaderboardUser] {
        var result = users

        // Filter by friends
        if showFriendsOnly {
            result = result.filter { friends.contains($0.id) || $0.id == currentUserID }
        }

        // Hide 0-step users (default ON, always keep current user visible)
        let hideZero = UserDefaults.standard.object(forKey: "hide_zero_steps_users") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "hide_zero_steps_users")
        if hideZero {
            result = result.filter { $0.steps > 0 || $0.id == currentUserID }
        }

        return result
    }
    
    func loadFriends() {
        guard Auth.auth().currentUser != nil else { return }
        
        db.collection("users").document(currentUserID).getDocument { [weak self] snapshot, error in
            if let data = snapshot?.data(), let friendsList = data["friends"] as? [String] {
                DispatchQueue.main.async {
                    self?.friends = Set(friendsList)
                }
            }
        }
    }
    
    func addFriend(userId: String) {
        guard Auth.auth().currentUser != nil else { return }
        
        friends.insert(userId)
        
        db.collection("users").document(currentUserID).setData([
            "friends": Array(friends)
        ], merge: true)
    }
    
    func removeFriend(userId: String) {
        guard Auth.auth().currentUser != nil else { return }
        
        friends.remove(userId)
        
        db.collection("users").document(currentUserID).setData([
            "friends": Array(friends)
        ], merge: true)
    }
    
    func isFriend(userId: String) -> Bool {
        return friends.contains(userId)
    }

    // MARK: - Friend Invite Link (Bidirectional)

    @Published var friendInviteCode: String? = nil

    private let friendInviteCharset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    /// Generate or retrieve the current user's friend invite code.
    /// Code is cached in UserDefaults and Firestore.
    /// Cache key scoped to the current user
    private var friendInviteCacheKey: String {
        "friendInviteCode_\(currentUserID)"
    }

    func generateFriendInviteCode(completion: @escaping (String) -> Void) {
        guard let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous else {
            completion("")
            return
        }

        // Return in-memory cache if it matches the current user
        if let cached = friendInviteCode, !cached.isEmpty {
            completion(cached)
            return
        }

        // Check UserDefaults cache scoped to this user
        if let savedCode = UserDefaults.standard.string(forKey: friendInviteCacheKey), !savedCode.isEmpty {
            friendInviteCode = savedCode
            completion(savedCode)
            return
        }

        // Check Firestore for an existing code for this user
        db.collection("friendInvites")
            .whereField("creatorId", isEqualTo: currentUser.uid)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let doc = snapshot?.documents.first {
                    // Found existing code in Firestore
                    let code = doc.documentID
                    self.friendInviteCode = code
                    UserDefaults.standard.set(code, forKey: self.friendInviteCacheKey)
                    completion(code)
                    return
                }

                // Generate new 6-char code
                let code = String((0..<6).map { _ in self.friendInviteCharset.randomElement()! })

                let data: [String: Any] = [
                    "creatorId": currentUser.uid,
                    "createdAt": FieldValue.serverTimestamp()
                ]

                self.db.collection("friendInvites").document(code).setData(data) { error in
                    self.friendInviteCode = code
                    UserDefaults.standard.set(code, forKey: self.friendInviteCacheKey)
                    completion(code)
                }
            }
    }

    /// Clear cached invite code (call on logout/account switch)
    func clearFriendInviteCache() {
        friendInviteCode = nil
        // Clean up legacy global key if it exists
        UserDefaults.standard.removeObject(forKey: "friendInviteCode")
    }

    /// Accept a friend invite: adds both users to each other's friend list.
    func acceptFriendInvite(code: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])))
            return
        }

        let cleanCode = code.trimmingCharacters(in: .whitespaces).uppercased()

        db.collection("friendInvites").document(cleanCode).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data(), let creatorId = data["creatorId"] as? String else {
                completion(.failure(NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid invite code"])))
                return
            }

            if creatorId == currentUser.uid {
                completion(.failure(NSError(domain: "", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot add yourself as a friend"])))
                return
            }

            // Check if already friends
            if self.friends.contains(creatorId) {
                completion(.success("Already friends"))
                return
            }

            // Add creator to current user's friends
            self.addFriend(userId: creatorId)

            // Add current user to creator's friends (bidirectional)
            self.db.collection("users").document(creatorId).setData([
                "friends": FieldValue.arrayUnion([currentUser.uid])
            ], merge: true)

            // Get creator's name for confirmation
            self.db.collection("leaderboard").document(creatorId).getDocument { snapshot, _ in
                let name = snapshot?.data()?["name"] as? String ?? "User"
                completion(.success(name))
            }
        }
    }

    /// Get share text with friend invite deep link.
    static let webDomain = "step1-a9d46.web.app"

    func getFriendInviteShareText(completion: @escaping (String) -> Void) {
        guard let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous else {
            completion("Join me on StePlease! 🚶‍♂️\n\nhttps://apps.apple.com/rs/app/steplease-step-tracker/id6758054873")
            return
        }
        generateFriendInviteCode { code in
            let link = "https://\(LeaderboardManager.webDomain)/friend/\(code)"
            let text = "Add me as a friend on StePlease! 🚶‍♂️\n\n\(link)"
            completion(text)
        }
    }

    func getFriendInviteShareItems(completion: @escaping ([Any]) -> Void) {
        getFriendInviteShareText { text in
            DispatchQueue.main.async { completion([text]) }
        }
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
