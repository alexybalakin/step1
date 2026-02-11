//
//  GroupManager.swift
//  Step1
//
//  Custom Groups Management
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Group Model
struct CustomGroup: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var description: String
    var adminId: String
    var inviteCode: String
    var members: [String]
    var createdAt: Date
    
    var memberCount: Int {
        members.count
    }
    
    // Alias for compatibility
    var joinCode: String {
        inviteCode
    }
    
    // Check if current user is the creator/admin
    var isCreator: Bool {
        Auth.auth().currentUser?.uid == adminId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CustomGroup, rhs: CustomGroup) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Group Manager
class GroupManager: ObservableObject {
    @Published var userGroups: [CustomGroup] = []
    @Published var isLoading = false
    @Published var selectedGroupId: String? = nil
    
    private let db = Firestore.firestore()
    
    var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    init() {
        loadUserGroups()
    }
    
    // MARK: - Load User's Groups
    func loadUserGroups() {
        guard !currentUserID.isEmpty else { return }
        
        isLoading = true
        
        db.collection("groups")
            .whereField("members", arrayContains: currentUserID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
                if let error = error {
                    print("Error loading groups: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.userGroups = []
                    }
                    return
                }
                
                let groups = documents.compactMap { doc -> CustomGroup? in
                    let data = doc.data()
                    return CustomGroup(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "",
                        description: data["description"] as? String ?? "",
                        adminId: data["adminId"] as? String ?? "",
                        inviteCode: data["inviteCode"] as? String ?? "",
                        members: data["members"] as? [String] ?? [],
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
                
                DispatchQueue.main.async {
                    self.userGroups = groups.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }
    
    // MARK: - Create New Group
    func createGroup(name: String, description: String, completion: @escaping (Result<CustomGroup, Error>) -> Void) {
        guard !currentUserID.isEmpty else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])))
            return
        }
        
        let groupId = UUID().uuidString
        let inviteCode = generateInviteCode()
        
        let groupData: [String: Any] = [
            "name": name,
            "description": description,
            "adminId": currentUserID,
            "inviteCode": inviteCode,
            "members": [currentUserID],
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("groups").document(groupId).setData(groupData) { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // Write invite code to public lookup collection
            self?.db.collection("groupInvites").document(inviteCode).setData([
                "groupId": groupId,
                "groupName": name,
                "adminId": self?.currentUserID ?? "",
                "createdAt": FieldValue.serverTimestamp()
            ])

            // Add group to user's groups list
            self?.db.collection("users").document(self?.currentUserID ?? "").updateData([
                "groups": FieldValue.arrayUnion([groupId])
            ])
            
            let group = CustomGroup(
                id: groupId,
                name: name,
                description: description,
                adminId: self?.currentUserID ?? "",
                inviteCode: inviteCode,
                members: [self?.currentUserID ?? ""],
                createdAt: Date()
            )
            
            completion(.success(group))
        }
    }
    
    // MARK: - Join Group by Invite Code
    func joinGroup(inviteCode: String, completion: @escaping (Result<CustomGroup, Error>) -> Void) {
        guard !currentUserID.isEmpty else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])))
            return
        }

        let cleanCode = inviteCode.trimmingCharacters(in: .whitespaces).uppercased()

        // Step 1: Look up invite code in public groupInvites collection
        db.collection("groupInvites").document(cleanCode).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                // Fallback: try direct query on groups collection
                self.joinGroupByQuery(inviteCode: cleanCode, completion: completion)
                return
            }

            if let data = snapshot?.data(), let groupId = data["groupId"] as? String {
                // Found via lookup — join directly by groupId
                self.joinGroupById(groupId: groupId, inviteCode: cleanCode, completion: completion)
            } else {
                // Not found in lookup — fallback to query
                self.joinGroupByQuery(inviteCode: cleanCode, completion: completion)
            }
        }
    }

    private func joinGroupById(groupId: String, inviteCode: String, completion: @escaping (Result<CustomGroup, Error>) -> Void) {
        db.collection("groups").document(groupId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data() else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Group not found"])))
                return
            }

            let members = data["members"] as? [String] ?? []
            if members.contains(self.currentUserID) {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Already a member"])))
                return
            }

            // Add user to group
            self.db.collection("groups").document(groupId).updateData([
                "members": FieldValue.arrayUnion([self.currentUserID])
            ]) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Add group to user's list
                self.db.collection("users").document(self.currentUserID).updateData([
                    "groups": FieldValue.arrayUnion([groupId])
                ])

                let group = CustomGroup(
                    id: groupId,
                    name: data["name"] as? String ?? "",
                    description: data["description"] as? String ?? "",
                    adminId: data["adminId"] as? String ?? "",
                    inviteCode: data["inviteCode"] as? String ?? "",
                    members: members + [self.currentUserID],
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )

                completion(.success(group))
            }
        }
    }

    private func joinGroupByQuery(inviteCode: String, completion: @escaping (Result<CustomGroup, Error>) -> Void) {
        db.collection("groups")
            .whereField("inviteCode", isEqualTo: inviteCode)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let doc = snapshot?.documents.first else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Group not found. Check the code and try again."])))
                    return
                }

                let groupId = doc.documentID
                self.joinGroupById(groupId: groupId, inviteCode: inviteCode, completion: completion)
            }
    }
    
    // MARK: - Leave Group
    func leaveGroup(groupId: String, completion: @escaping (Error?) -> Void) {
        guard !currentUserID.isEmpty else {
            completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not logged in"]))
            return
        }
        
        // Check if user is admin
        if let group = userGroups.first(where: { $0.id == groupId }), group.adminId == currentUserID {
            // Admin leaving - delete group or transfer ownership
            if group.members.count == 1 {
                // Only member, delete group
                deleteGroup(groupId: groupId, completion: completion)
            } else {
                completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Admin must transfer ownership before leaving"]))
            }
            return
        }
        
        // Remove user from group
        db.collection("groups").document(groupId).updateData([
            "members": FieldValue.arrayRemove([currentUserID])
        ]) { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            // Remove group from user's list
            self?.db.collection("users").document(self?.currentUserID ?? "").updateData([
                "groups": FieldValue.arrayRemove([groupId])
            ])
            
            completion(nil)
        }
    }
    
    // MARK: - Delete Group (Admin only)
    func deleteGroup(groupId: String, completion: @escaping (Error?) -> Void) {
        guard !currentUserID.isEmpty else {
            completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not logged in"]))
            return
        }
        
        guard let group = userGroups.first(where: { $0.id == groupId }), group.adminId == currentUserID else {
            completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Only admin can delete group"]))
            return
        }
        
        // Remove group from all members' lists
        for memberId in group.members {
            db.collection("users").document(memberId).updateData([
                "groups": FieldValue.arrayRemove([groupId])
            ])
        }
        
        // Delete group document
        db.collection("groups").document(groupId).delete(completion: completion)
    }
    
    // MARK: - Get Group Members with Details
    func getGroupMembers(groupId: String, dates: [String], completion: @escaping ([LeaderboardUser]) -> Void) {
        guard let group = userGroups.first(where: { $0.id == groupId }) else {
            completion([])
            return
        }

        let memberIds = group.members
        guard !memberIds.isEmpty else {
            completion([])
            return
        }

        db.collection("leaderboard")
            .whereField(FieldPath.documentID(), in: memberIds)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                var users: [LeaderboardUser] = []
                let fetchGroup = DispatchGroup()

                for doc in documents {
                    let data = doc.data()
                    let name = data["name"] as? String ?? "Unknown"
                    let isDemo = data["isDemo"] as? Bool ?? false

                    if isDemo {
                        let steps = data["steps"] as? Int ?? 0
                        users.append(LeaderboardUser(id: doc.documentID, name: name, steps: steps))
                    } else {
                        fetchGroup.enter()
                        self.fetchStepsForDates(userId: doc.documentID, dates: dates) { totalSteps in
                            users.append(LeaderboardUser(id: doc.documentID, name: name, steps: totalSteps))
                            fetchGroup.leave()
                        }
                    }
                }

                fetchGroup.notify(queue: .main) {
                    completion(users)
                }
            }
    }

    /// Fetch sum of steps across multiple dates from daily subcollection
    private func fetchStepsForDates(userId: String, dates: [String], completion: @escaping (Int) -> Void) {
        guard !dates.isEmpty else {
            completion(0)
            return
        }

        let dailyRef = db.collection("leaderboard").document(userId).collection("daily")

        // Firestore 'in' query limited to 10 items, batch if needed
        let chunks = stride(from: 0, to: dates.count, by: 10).map {
            Array(dates[$0..<min($0 + 10, dates.count)])
        }

        var totalSteps = 0
        let chunkGroup = DispatchGroup()

        for chunk in chunks {
            chunkGroup.enter()
            dailyRef.whereField(FieldPath.documentID(), in: chunk).getDocuments { snapshot, _ in
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
            completion(totalSteps)
        }
    }
    
    // MARK: - Update Group Info (Admin only)
    func updateGroup(groupId: String, name: String, description: String, completion: @escaping (Error?) -> Void) {
        guard !currentUserID.isEmpty else {
            completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not logged in"]))
            return
        }
        
        guard let group = userGroups.first(where: { $0.id == groupId }), group.adminId == currentUserID else {
            completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Only admin can update group"]))
            return
        }
        
        db.collection("groups").document(groupId).updateData([
            "name": name,
            "description": description
        ]) { [weak self] error in
            if error == nil {
                // Also update groupName in the invite lookup collection
                self?.db.collection("groupInvites").document(group.inviteCode).updateData([
                    "groupName": name
                ])
            }
            completion(error)
        }
    }
    
    // MARK: - Generate Invite Code
    private func generateInviteCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excluded confusing chars
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    
    // MARK: - Generate Share Link (link-only, no code needed)
    func getShareLink(for group: CustomGroup) -> URL {
        return URL(string: "https://\(GroupManager.webDomain)/join/\(group.inviteCode)")!
    }
    
    func getAppStoreLink() -> String {
        return "https://apps.apple.com/rs/app/steplease-step-tracker/id6758054873"
    }
    
    static let webDomain = "step1-a9d46.web.app"

    func getShareText(for group: CustomGroup) -> String {
        let link = "https://\(GroupManager.webDomain)/join/\(group.inviteCode)"
        return "Join my group \"\(group.name)\" on StePlease! 🚶‍♂️\n\n\(link)"
    }

    func getShareItems(for group: CustomGroup) -> [Any] {
        let text = getShareText(for: group)
        return [text]
    }

    // MARK: - Join Group by Deep Link
    func joinGroupFromLink(code: String, completion: @escaping (Result<CustomGroup, Error>) -> Void) {
        joinGroup(inviteCode: code, completion: completion)
    }
    
    // MARK: - Parse deep link URL
    func parseJoinURL(_ url: URL) -> String? {
        // Handle: steplease://join/XXXXXX
        if url.scheme == "steplease" && url.host == "join" {
            let code = url.pathComponents.last ?? ""
            return code.isEmpty ? nil : code
        }
        // Handle: steplease://join?code=XXXXXX
        if url.scheme == "steplease",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let codeItem = components.queryItems?.first(where: { $0.name == "code" }) {
            return codeItem.value
        }
        return nil
    }
}
