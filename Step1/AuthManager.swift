//
//  AuthManager.swift
//  Step1
//
//  Created by Alex Balakin on 1/19/26.
//

import SwiftUI
import AuthenticationServices
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userID: String = ""
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var isLoading = false
    @Published var authProvider: String = "" // "apple", "google", "email", or "anonymous"
    
    // MARK: - FIX #9: Check if user is anonymous
    var isAnonymous: Bool {
        return authProvider == "anonymous" || Auth.auth().currentUser?.isAnonymous == true
    }
    
    private let db = Firestore.firestore()
    
    override init() {
        super.init()
        checkAuthStatus()
        // FIX #2: Fix existing duplicate names on app launch
        fixDuplicateNames()
    }
    
    // MARK: - Check saved auth status
    func checkAuthStatus() {
        // Check Firebase Auth
        if let currentUser = Auth.auth().currentUser {
            self.isAuthenticated = true
            self.userID = currentUser.uid
            self.userEmail = currentUser.email ?? ""
            self.authProvider = UserDefaults.standard.string(forKey: "authProvider") ?? ""
            
            // Load name from Firestore
            loadUserNameFromFirestore()
            return
        }
        
        // Check saved Apple credentials
        guard let savedUserID = UserDefaults.standard.string(forKey: "userID") else {
            return
        }
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: savedUserID) { [weak self] credentialState, error in
            DispatchQueue.main.async {
                switch credentialState {
                case .authorized:
                    self?.isAuthenticated = true
                    self?.userID = savedUserID
                    self?.userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
                    self?.authProvider = "apple"
                    self?.loadUserNameFromFirestore()
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Load user name from Firestore
    private func loadUserNameFromFirestore() {
        guard !userID.isEmpty else { return }
        
        db.collection("users").document(userID).getDocument { [weak self] snapshot, error in
            if let data = snapshot?.data(), let name = data["name"] as? String, !name.isEmpty {
                DispatchQueue.main.async {
                    self?.userName = name
                    UserDefaults.standard.set(name, forKey: "userName")
                }
            } else {
                // Fallback to local storage or generate name
                DispatchQueue.main.async {
                    let localName = UserDefaults.standard.string(forKey: "userName") ?? ""
                    if localName.isEmpty {
                        // FIX #2: Генерируем имя для пользователя без имени
                        self?.generateAndSaveUserName()
                    } else {
                        self?.userName = localName
                    }
                }
            }
        }
    }
    
    // MARK: - FIX #2: Generate unique user name
    private func generateAndSaveUserName() {
        db.collection("leaderboard").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            var usedNumbers: Set<Int> = []
            
            // Collect existing User N numbers
            if let documents = snapshot?.documents {
                for doc in documents {
                    if let name = doc.data()["name"] as? String, name.hasPrefix("User ") {
                        if let num = Int(name.dropFirst(5)) {
                            usedNumbers.insert(num)
                        }
                    }
                }
            }
            
            // Find next available number
            var nextNumber = 1
            while usedNumbers.contains(nextNumber) {
                nextNumber += 1
            }
            
            let newName = "User \(nextNumber)"
            
            DispatchQueue.main.async {
                self.userName = newName
                UserDefaults.standard.set(newName, forKey: "userName")
                self.saveUserNameToFirestore(newName)
            }
        }
    }
    
    // MARK: - Save user name to Firestore
    func saveUserNameToFirestore(_ name: String) {
        guard !userID.isEmpty else { return }
        
        // FIX #2: Проверяем, что имя не пустое
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty ? userName : name
        guard !finalName.isEmpty else { return }
        
        // FIX #1: Check name uniqueness before saving
        checkNameUniqueness(name: finalName, forUserID: userID) { [weak self] uniqueName in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.userName = uniqueName
                UserDefaults.standard.set(uniqueName, forKey: "userName")
            }
            
            self.db.collection("users").document(self.userID).setData([
                "name": uniqueName,
                "email": self.userEmail,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            // Also update in leaderboard
            self.db.collection("leaderboard").document(self.userID).setData([
                "name": uniqueName,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }
    
    // MARK: - FIX #1: Check name uniqueness
    func checkNameUniqueness(name: String, forUserID uid: String, completion: @escaping (String) -> Void) {
        db.collection("leaderboard").whereField("name", isEqualTo: name).getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                completion(name)
                return
            }
            
            // Filter out the current user's document
            let otherUsersWithSameName = documents.filter { $0.documentID != uid }
            
            if otherUsersWithSameName.isEmpty {
                // Name is unique
                completion(name)
            } else {
                // Name already taken — find next available suffix
                self.db.collection("leaderboard").getDocuments { allSnapshot, _ in
                    guard let allDocs = allSnapshot?.documents else {
                        completion(name)
                        return
                    }
                    
                    let allNames = Set(allDocs.filter { $0.documentID != uid }.compactMap { $0.data()["name"] as? String })
                    
                    var suffix = 2
                    var candidate = "\(name) \(suffix)"
                    while allNames.contains(candidate) {
                        suffix += 1
                        candidate = "\(name) \(suffix)"
                    }
                    completion(candidate)
                }
            }
        }
    }
    
    // MARK: - FIX #2: Fix existing duplicate names in Firestore (run once)
    func fixDuplicateNames() {
        db.collection("leaderboard").getDocuments { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else { return }
            
            // Group documents by name
            var nameGroups: [String: [(id: String, data: [String: Any])]] = [:]
            for doc in documents {
                let name = (doc.data()["name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
                if name.isEmpty { continue }
                nameGroups[name, default: []].append((id: doc.documentID, data: doc.data()))
            }
            
            // For each group with duplicates, rename extras
            var allUsedNames = Set(nameGroups.keys)
            
            for (name, group) in nameGroups where group.count > 1 {
                // Keep the first user's name, rename the rest
                for i in 1..<group.count {
                    var suffix = 2
                    var newName = "\(name) \(suffix)"
                    while allUsedNames.contains(newName) {
                        suffix += 1
                        newName = "\(name) \(suffix)"
                    }
                    allUsedNames.insert(newName)
                    
                    let docID = group[i].id
                    self.db.collection("leaderboard").document(docID).updateData(["name": newName])
                    self.db.collection("users").document(docID).updateData(["name": newName])
                    
                    // If it's the current user, update locally too
                    if docID == self.userID {
                        DispatchQueue.main.async {
                            self.userName = newName
                            UserDefaults.standard.set(newName, forKey: "userName")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Handle Sign in with Apple
    // MARK: - Apple Sign In (programmatic trigger)
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
    
    func handleSignInWithApple(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                
                var name = ""
                if let fullName = appleIDCredential.fullName {
                    let givenName = fullName.givenName ?? ""
                    let familyName = fullName.familyName ?? ""
                    name = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
                }
                
                let email = appleIDCredential.email ?? ""
                
                // Get token for Firebase
                guard let identityToken = appleIDCredential.identityToken,
                      let tokenString = String(data: identityToken, encoding: .utf8) else {
                    print("Unable to get identity token")
                    signIn(userID: userIdentifier, name: name, email: email, provider: "apple")
                    return
                }
                
                // Sign in to Firebase with Apple credential
                let credential = OAuthProvider.appleCredential(
                    withIDToken: tokenString,
                    rawNonce: nil,
                    fullName: appleIDCredential.fullName
                )
                
                Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                    if let error = error {
                        print("Firebase Apple auth error: \(error.localizedDescription)")
                        self?.signIn(userID: userIdentifier, name: name, email: email, provider: "apple")
                        return
                    }
                    
                    guard let firebaseUser = authResult?.user else { return }
                    
                    let finalEmail = email.isEmpty ? (firebaseUser.email ?? "") : email
                    
                    DispatchQueue.main.async {
                        // Pass name only if it's from Apple (first sign in), otherwise load from Firestore
                        self?.signIn(userID: firebaseUser.uid, name: name, email: finalEmail, provider: "apple")
                    }
                }
            }
            
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                print("User canceled Sign in with Apple")
            } else {
                print("Sign in with Apple failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("No client ID found")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("No root view controller found")
            return
        }
        
        isLoading = true
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
            }
            
            if let error = error {
                print("Google Sign In error: \(error.localizedDescription)")
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("No user or token")
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                if let error = error {
                    print("Firebase auth error: \(error.localizedDescription)")
                    return
                }
                
                guard let firebaseUser = authResult?.user else { return }
                
                DispatchQueue.main.async {
                    // Don't use Google display name, load from Firestore instead
                    self?.signIn(
                        userID: firebaseUser.uid,
                        name: "", // Will be loaded from Firestore
                        email: firebaseUser.email ?? user.profile?.email ?? "",
                        provider: "google"
                    )
                }
            }
        }
    }
    
    // MARK: - Email Sign In
    func signInWithEmail(email: String, password: String, completion: @escaping (String?) -> Void) {
        print("📧 signInWithEmail called with email: \(email)")
        isLoading = true
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            print("📧 Firebase response received")
            
            DispatchQueue.main.async {
                self?.isLoading = false
            }
            
            if let error = error {
                print("📧 Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(error.localizedDescription)
                }
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                print("📧 No user in response")
                DispatchQueue.main.async {
                    completion("Unknown error")
                }
                return
            }
            
            print("📧 Success! User: \(firebaseUser.uid)")
            DispatchQueue.main.async {
                self?.signIn(
                    userID: firebaseUser.uid,
                    name: "", // Will be loaded from Firestore
                    email: firebaseUser.email ?? email,
                    provider: "email"
                )
                completion(nil)
            }
        }
    }
    
    // MARK: - Anonymous Sign In - FIX #2: присваиваем имя Guest
    func signInAnonymously() {
        isLoading = true
        
        Auth.auth().signInAnonymously { [weak self] authResult, error in
            DispatchQueue.main.async {
                self?.isLoading = false
            }
            
            if let error = error {
                print("Anonymous auth error: \(error.localizedDescription)")
                return
            }
            
            guard let firebaseUser = authResult?.user else { return }
            
            DispatchQueue.main.async {
                // FIX #2: Генерируем уникальное имя Guest N
                self?.signIn(
                    userID: firebaseUser.uid,
                    name: "", // Будет сгенерировано
                    email: "",
                    provider: "anonymous"
                )
            }
        }
    }
    
    // MARK: - Email Register
    func registerWithEmail(email: String, password: String, name: String, completion: @escaping (String?) -> Void) {
        isLoading = true
        
        // FIX #2: Проверяем, что имя не пустое
        let finalName = name.trimmingCharacters(in: .whitespaces)
        guard !finalName.isEmpty else {
            isLoading = false
            completion("Name cannot be empty")
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                self?.isLoading = false
            }
            
            if let error = error {
                completion(error.localizedDescription)
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                completion("Unknown error")
                return
            }
            
            DispatchQueue.main.async {
                self?.signIn(
                    userID: firebaseUser.uid,
                    name: finalName,
                    email: firebaseUser.email ?? email,
                    provider: "email"
                )
                // Save name to Firestore
                self?.saveUserNameToFirestore(finalName)
                completion(nil)
            }
        }
    }
    
    // MARK: - Reset Password
    func resetPassword(email: String, completion: @escaping (String?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(error.localizedDescription)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - Sign In
    func signIn(userID: String, name: String, email: String, provider: String) {
        self.userID = userID
        self.userEmail = email
        self.isAuthenticated = true
        self.authProvider = provider
        
        UserDefaults.standard.set(userID, forKey: "userID")
        UserDefaults.standard.set(provider, forKey: "authProvider")
        if !email.isEmpty {
            UserDefaults.standard.set(email, forKey: "userEmail")
        }
        
        // Load or save name
        if name.isEmpty {
            loadUserNameFromFirestore()
        } else {
            self.userName = name
            UserDefaults.standard.set(name, forKey: "userName")
            saveUserNameToFirestore(name)
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        // Sign out from Firebase
        try? Auth.auth().signOut()
        
        // Sign out from Google
        GIDSignIn.sharedInstance.signOut()
        
        isAuthenticated = false
        userID = ""
        userName = ""
        userEmail = ""
        authProvider = ""
        
        UserDefaults.standard.removeObject(forKey: "userID")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "authProvider")
    }
    
    // MARK: - Delete Account
    func deleteAccount(completion: @escaping (String?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion("No user logged in")
            return
        }
        
        let userId = user.uid
        
        // Delete user data from Firestore
        let batch = db.batch()
        
        // Delete from users collection
        batch.deleteDocument(db.collection("users").document(userId))
        
        // Delete from leaderboard collection
        batch.deleteDocument(db.collection("leaderboard").document(userId))
        
        batch.commit { [weak self] error in
            if let error = error {
                print("Error deleting Firestore data: \(error.localizedDescription)")
            }
            
            // Delete Firebase Auth account
            user.delete { error in
                if let error = error {
                    completion(error.localizedDescription)
                    return
                }
                
                DispatchQueue.main.async {
                    self?.signOut()
                    completion(nil)
                }
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        handleSignInWithApple(result: .success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        handleSignInWithApple(result: .failure(error))
    }
}
