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
import GoogleSignIn

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userID: String = ""
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var isLoading = false
    @Published var authProvider: String = "" // "apple" or "google"
    
    init() {
        checkAuthStatus()
    }
    
    // MARK: - Check saved auth status
    func checkAuthStatus() {
        // Check Firebase Auth
        if let currentUser = Auth.auth().currentUser {
            self.isAuthenticated = true
            self.userID = currentUser.uid
            self.userName = currentUser.displayName ?? UserDefaults.standard.string(forKey: "userName") ?? ""
            self.userEmail = currentUser.email ?? ""
            self.authProvider = UserDefaults.standard.string(forKey: "authProvider") ?? ""
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
                    self?.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
                    self?.userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
                    self?.authProvider = "apple"
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Handle Sign in with Apple
    func handleSignInWithApple(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = appleIDCredential.user
                
                var name = ""
                if let fullName = appleIDCredential.fullName {
                    let givenName = fullName.givenName ?? ""
                    let familyName = fullName.familyName ?? ""
                    name = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
                }
                
                let email = appleIDCredential.email ?? ""
                
                let savedName = UserDefaults.standard.string(forKey: "userName") ?? ""
                let savedEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
                
                let finalName = name.isEmpty ? savedName : name
                let finalEmail = email.isEmpty ? savedEmail : email
                
                signIn(userID: userID, name: finalName, email: finalEmail, provider: "apple")
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
                    self?.signIn(
                        userID: firebaseUser.uid,
                        name: firebaseUser.displayName ?? user.profile?.name ?? "",
                        email: firebaseUser.email ?? user.profile?.email ?? "",
                        provider: "google"
                    )
                }
            }
        }
    }
    
    // MARK: - Sign In
    func signIn(userID: String, name: String, email: String, provider: String) {
        self.userID = userID
        self.userName = name.isEmpty ? "User" : name
        self.userEmail = email
        self.isAuthenticated = true
        self.authProvider = provider
        
        UserDefaults.standard.set(userID, forKey: "userID")
        UserDefaults.standard.set(provider, forKey: "authProvider")
        if !name.isEmpty {
            UserDefaults.standard.set(name, forKey: "userName")
        }
        if !email.isEmpty {
            UserDefaults.standard.set(email, forKey: "userEmail")
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
}
