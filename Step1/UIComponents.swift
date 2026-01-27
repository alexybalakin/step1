//
//  UIComponents.swift
//  Step1
//
//  Created by Alex Balakin on 1/19/26.
//

import SwiftUI
import AuthenticationServices

// MARK: - Splash Screen
struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color(hex: "000200")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo image
                Image("splash_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Text("StePlease")
                        .font(.system(size: 42, weight: .semibold))
                        .tracking(-0.04 * 42) // -4% spacing
                        .foregroundColor(.white)
                    
                    Text("Start, keep going")
                        .font(.system(size: 17, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "848484"))
                }
                
                Spacer()
                    .frame(height: 120)
            }
        }
    }
}

// MARK: - Onboarding View (Goal Selection)
struct OnboardingView: View {
    @ObservedObject var healthManager: HealthManager
    @Binding var isOnboardingComplete: Bool
    let userID: String
    @State private var selectedGoal: Int = 10000
    @State private var customGoalText: String = ""
    @State private var showCustomInput: Bool = false
    @FocusState private var isCustomInputFocused: Bool
    
    let goalOptions = [5000, 10000, 15000]
    
    var body: some View {
        ZStack {
            Color(hex: "000200")
                .ignoresSafeArea()
                .onTapGesture {
                    isCustomInputFocused = false
                }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 60)
                        
                        VStack(spacing: 16) {
                            Text("🎯")
                                .font(.system(size: 60))
                            
                            Text("Set Your Daily Goal")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("How many steps do you want to walk each day?")
                                .font(.system(size: 17))
                                .foregroundColor(Color(hex: "8E8E93"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Spacer().frame(height: 20)
                        
                        // Goal options
                        VStack(spacing: 12) {
                            ForEach(goalOptions, id: \.self) { goal in
                                Button(action: {
                                    isCustomInputFocused = false
                                    selectedGoal = goal
                                    showCustomInput = false
                                    customGoalText = ""
                                }) {
                                    HStack {
                                        Text("\(goal.formatted()) steps")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(selectedGoal == goal && !showCustomInput ? .black : .white)
                                        
                                        Spacer()
                                        
                                        if selectedGoal == goal && !showCustomInput {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.black)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .frame(height: 56)
                                    .background(selectedGoal == goal && !showCustomInput ? Color(hex: "34C759") : Color(hex: "1A1A1C"))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Custom input option
                            HStack {
                                if showCustomInput {
                                    TextField("", text: $customGoalText, prompt: Text("Enter steps").foregroundColor(Color(hex: "8E8E93")))
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .keyboardType(.numberPad)
                                        .focused($isCustomInputFocused)
                                        .onChange(of: customGoalText) { _, newValue in
                                            if let value = Int(newValue), value > 0 {
                                                selectedGoal = value
                                            }
                                        }
                                } else {
                                    Text("Custom goal")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                if showCustomInput {
                                    Button(action: {
                                        isCustomInputFocused = false
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: "34C759"))
                                    }
                                } else {
                                    Image(systemName: "pencil")
                                        .foregroundColor(Color(hex: "8E8E93"))
                                }
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .background(Color(hex: "1A1A1C"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(showCustomInput ? Color(hex: "34C759") : Color.clear, lineWidth: 2)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !showCustomInput {
                                    showCustomInput = true
                                    isCustomInputFocused = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer().frame(height: 40)
                        
                        // Continue button
                        Button {
                            isCustomInputFocused = false
                            healthManager.dailyGoal = selectedGoal
                            healthManager.saveDailyGoal()
                            UserDefaults.standard.set(true, forKey: "onboarding_\(userID)")
                            isOnboardingComplete = true
                        } label: {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(hex: "34C759"))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .id("continueButton")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: isCustomInputFocused) { _, focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo("continueButton", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @State private var showEmailLogin = false
    @State private var showEmailRegister = false
    
    var body: some View {
        ZStack {
            Color(hex: "000200")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image("splash_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                    
                    Text("StePlease")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Track your steps, compete with friends")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    // Sign in with Apple
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            authManager.handleSignInWithApple(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    
                    // Sign in with Google
                    Button(action: {
                        authManager.signInWithGoogle()
                    }) {
                        HStack(spacing: 12) {
                            // Google colored logo
                            GoogleLogo()
                                .frame(width: 20, height: 20)
                            Text("Sign in with Google")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading)
                    .opacity(authManager.isLoading ? 0.6 : 1)
                    
                    // Sign in with Email
                    Button(action: {
                        showEmailLogin = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 20))
                            Text("Sign in with Email")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "3A3A3C"), lineWidth: 1)
                        )
                    }
                    // Continue without registration
                                        Button(action: {
                                            authManager.signInAnonymously()
                                        }) {
                                            Text("Continue without registration")
                                                                        .font(.system(size: 17, weight: .medium))
                                            .foregroundColor(Color(hex: "8E8E93"))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(Color(hex: "1A1A1C"))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color(hex: "3A3A3C"), lineWidth: 1)
                                            )
                                        }
                                        .disabled(authManager.isLoading)
                                        .opacity(authManager.isLoading ? 0.6 : 1)
                    // Register link
                    Button(action: {
                        showEmailRegister = true
                    }) {
                        Text("Don't have an account? ")
                            .foregroundColor(Color(hex: "8E8E93"))
                        + Text("Register")
                            .foregroundColor(Color(hex: "34C759"))
                    }
                    .font(.system(size: 15))
                    .padding(.top, 8)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
            
            // Loading overlay
            if authManager.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEmailLogin) {
            EmailLoginView(authManager: authManager, isRegistering: false)
        }
        .sheet(isPresented: $showEmailRegister) {
            EmailLoginView(authManager: authManager, isRegistering: true)
        }
    }
}

// MARK: - Email Login/Register View
struct EmailLoginView: View {
    @ObservedObject var authManager: AuthManager
    let isRegistering: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text(isRegistering ? "Create Account" : "Welcome Back")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(isRegistering ? "Sign up to get started" : "Sign in to continue")
                                .font(.system(size: 17))
                                .foregroundColor(Color(hex: "8E8E93"))
                        }
                        .padding(.top, 40)
                        
                        VStack(spacing: 16) {
                            if isRegistering {
                                TextField("", text: $name, prompt: Text("Name").foregroundColor(Color(hex: "8E8E93")))
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .textContentType(.name)
                                    .autocapitalization(.words)
                            }
                            
                            TextField("", text: $email, prompt: Text("Email").foregroundColor(Color(hex: "8E8E93")))
                                .textFieldStyle(DarkTextFieldStyle())
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            SecureField("", text: $password, prompt: Text("Password").foregroundColor(Color(hex: "8E8E93")))
                                .textFieldStyle(DarkTextFieldStyle())
                                .textContentType(isRegistering ? .newPassword : .password)
                            
                            if isRegistering {
                                SecureField("", text: $confirmPassword, prompt: Text("Confirm Password").foregroundColor(Color(hex: "8E8E93")))
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .textContentType(.newPassword)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "FF3B30"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        Button {
                            handleSubmit()
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text(isRegistering ? "Create Account" : "Sign In")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "34C759"))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .disabled(isLoading)
                        
                        if !isRegistering {
                            Button(action: {
                                resetPassword()
                            }) {
                                Text("Forgot Password?")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(hex: "34C759"))
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "34C759"))
                }
            }
        }
    }
    
    func handleSubmit() {
        print("🔘 handleSubmit called")
        errorMessage = ""
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            print("🔘 Empty fields")
            return
        }
        
        print("🔘 Email: \(email), Password length: \(password.count)")
        
        if isRegistering {
            guard !name.isEmpty else {
                errorMessage = "Please enter your name"
                return
            }
            guard password == confirmPassword else {
                errorMessage = "Passwords don't match"
                return
            }
            guard password.count >= 6 else {
                errorMessage = "Password must be at least 6 characters"
                return
            }
            
            isLoading = true
            authManager.registerWithEmail(email: email, password: password, name: name) { error in
                isLoading = false
                if let error = error {
                    errorMessage = error
                } else {
                    dismiss()
                }
            }
        } else {
            isLoading = true
            authManager.signInWithEmail(email: email, password: password) { error in
                isLoading = false
                if let error = error {
                    errorMessage = error
                } else {
                    dismiss()
                }
            }
        }
    }
    
    func resetPassword() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        authManager.resetPassword(email: email) { error in
            if let error = error {
                errorMessage = error
            } else {
                errorMessage = "Password reset email sent!"
            }
        }
    }
}

// MARK: - Dark Text Field Style
struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color(hex: "1A1A1C"))
            .cornerRadius(12)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "3A3A3C"), lineWidth: 1)
            )
    }
}

// MARK: - Google Logo (colored)
struct GoogleLogo: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
            
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius = size * 0.4
                
                // Blue arc (right)
                Path { path in
                    path.addArc(center: center, radius: radius, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
                }
                .stroke(Color(red: 66/255, green: 133/255, blue: 244/255), lineWidth: size * 0.15)
                
                // Green arc (bottom)
                Path { path in
                    path.addArc(center: center, radius: radius, startAngle: .degrees(45), endAngle: .degrees(135), clockwise: false)
                }
                .stroke(Color(red: 52/255, green: 168/255, blue: 83/255), lineWidth: size * 0.15)
                
                // Yellow arc (left-bottom)
                Path { path in
                    path.addArc(center: center, radius: radius, startAngle: .degrees(135), endAngle: .degrees(180), clockwise: false)
                }
                .stroke(Color(red: 251/255, green: 188/255, blue: 5/255), lineWidth: size * 0.15)
                
                // Red arc (top)
                Path { path in
                    path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(315), clockwise: false)
                }
                .stroke(Color(red: 234/255, green: 67/255, blue: 53/255), lineWidth: size * 0.15)
                
                // Blue horizontal bar
                Rectangle()
                    .fill(Color(red: 66/255, green: 133/255, blue: 244/255))
                    .frame(width: size * 0.35, height: size * 0.15)
                    .position(x: center.x + size * 0.1, y: center.y)
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var healthManager: HealthManager
    @ObservedObject var leaderboardManager: LeaderboardManager
    @State private var showNameEditor = false
    @State private var showGoalEditor = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                    
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "ACCOUNT")
                        
                        VStack(spacing: 0) {
                            Button(action: { showNameEditor = true }) {
                                SettingsRowContent(
                                    icon: "person.circle.fill",
                                    title: "Name",
                                    value: authManager.userName.isEmpty ? "User" : authManager.userName,
                                    showChevron: true
                                )
                            }
                            
                            if !authManager.userEmail.isEmpty {
                                Divider()
                                    .background(Color(hex: "3A3A3C"))
                                    .padding(.leading, 52)
                                
                                SettingsRowContent(
                                    icon: "envelope.fill",
                                    title: "Email",
                                    value: authManager.userEmail,
                                    showChevron: false
                                )
                            }
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "GOALS")
                        
                        VStack(spacing: 0) {
                            Button(action: { showGoalEditor = true }) {
                                SettingsRowContent(
                                    icon: "figure.walk",
                                    title: "Daily Step Goal",
                                    value: "\(healthManager.dailyGoal.formatted()) steps",
                                    showChevron: true
                                )
                            }
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    // Invite Friend Card
                    InviteFriendCard()
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "LEGAL")
                        
                        VStack(spacing: 0) {
                            Button(action: {
                                if let url = URL(string: "https://alexeibalakin.notion.site/Privacy-Policy-Steplease-iOS-2ef3a7aec532804d84e8d9f72df27d28") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                SettingsRowContent(
                                    icon: "doc.text",
                                    title: "Privacy Policy",
                                    value: "",
                                    showChevron: true
                                )
                            }
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            authManager.signOut()
                        }) {
                            Text("Sign Out")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(hex: "FF3B30"))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Text("Delete Account")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "FF3B30"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(hex: "1A1A1C"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "FF3B30"), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            
            if isDeleting {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                VStack {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("Deleting account...")
                        .foregroundColor(.white)
                        .padding(.top, 16)
                }
            }
        }
        .sheet(isPresented: $showNameEditor) {
            NameEditorView(authManager: authManager)
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorView(goal: $healthManager.dailyGoal)
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                isDeleting = true
                authManager.deleteAccount { error in
                    isDeleting = false
                    if let error = error {
                        deleteError = error
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.")
        }
        .alert("Error", isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }
}

// MARK: - Name Editor View
struct NameEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var authManager: AuthManager
    @State private var newName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Change your name")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    
                    TextField("Name", text: $newName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(height: 60)
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    Button {
                        if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                            authManager.saveUserNameToFirestore(newName)
                            dismiss()
                        }
                    } label: {
                        Text("Save")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "34C759"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "34C759"))
                }
            }
        }
        .onAppear {
            newName = authManager.userName
        }
    }
}

// MARK: - Invite Friend Card
struct InviteFriendCard: View {
    @State private var showShareSheet = false
    @State private var showCopied = false
    let appStoreLink = "https://apps.apple.com/app/steplease" // Update with real link after release
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invite Friends")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Challenge your friends!")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
                
                Spacer()
                
                Text("👥")
                    .font(.system(size: 40))
            }
            
            HStack(spacing: 12) {
                // Copy Link
                Button {
                    UIPasteboard.general.string = appStoreLink
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopied = false
                    }
                } label: {
                    HStack {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied!" : "Copy Link")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(showCopied ? Color(hex: "34C759") : Color(hex: "2C2C2E"))
                    .cornerRadius(10)
                }
                
                // Share to Telegram
                Button {
                    let message = "Join me on StePlease! \(appStoreLink)"
                    let telegramURL = "tg://msg?text=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                    if let url = URL(string: telegramURL), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        showShareSheet = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Share")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: "0088CC"))
                    .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1A1A1C"))
        .cornerRadius(16)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Join me on StePlease! \(appStoreLink)"])
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Compact Invite Button (for Friends tab)
struct CompactInviteButton: View {
    @State private var showShareSheet = false
    let appStoreLink = "https://apps.apple.com/app/steplease"
    
    var body: some View {
        Button {
            showShareSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Invite")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "34C759"))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Join me on StePlease! \(appStoreLink)"])
        }
    }
}

struct SettingsSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(hex: "8E8E93"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }
}

struct SettingsRowContent: View {
    let icon: String
    let title: String
    let value: String
    let showChevron: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "34C759"))
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 17))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 17))
                .foregroundColor(Color(hex: "8E8E93"))
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "3A3A3C"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "34C759"))
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 17))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 17))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Top Navigation (Compact date selector)
struct TopNavigationView: View {
    @Binding var selectedPeriod: Int
    @Binding var currentDate: Date
    @ObservedObject var healthManager: HealthManager
    @State private var showCalendar = false
    
    var canGoForward: Bool {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        return calendar.startOfDay(for: tomorrow) <= calendar.startOfDay(for: Date())
    }
    
    var dateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(currentDate) {
            return "TODAY"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "MMM d"
            return formatter.string(from: currentDate).uppercased()
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                changeDate(by: -1)
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 28)
            }
            
            Button(action: {
                showCalendar = true
            }) {
                Text(dateString)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(minWidth: 70)
            }
            
            Button(action: {
                changeDate(by: 1)
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(canGoForward ? .white : Color(hex: "3A3A3C"))
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 28)
            }
            .disabled(!canGoForward)
        }
        .frame(height: 28)
        .background(Color(hex: "1A1A1C"))
        .cornerRadius(8)
        .fullScreenCover(isPresented: $showCalendar) {
            CalendarOverlayView(
                selectedDate: $currentDate,
                healthManager: healthManager,
                isPresented: $showCalendar
            )
        }
    }
    
    func changeDate(by value: Int) {
        let calendar = Calendar.current
        let newDate = calendar.date(byAdding: .day, value: value, to: currentDate) ?? currentDate
        
        if newDate <= Date() {
            withAnimation {
                currentDate = newDate
            }
        }
    }
}

// MARK: - Calendar Overlay View
struct CalendarOverlayView: View {
    @Binding var selectedDate: Date
    @ObservedObject var healthManager: HealthManager
    @Binding var isPresented: Bool
    @State private var displayedMonth: Date = Date()
    
    let calendar = Calendar.current
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    
    var canGoForward: Bool {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        let startOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth))!
        return startOfNextMonth <= Date()
    }
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }
    
    var daysInMonth: [Date?] {
        let interval = calendar.dateInterval(of: .month, for: displayedMonth)!
        let firstDay = interval.start
        
        var weekday = calendar.component(.weekday, from: firstDay)
        weekday = weekday == 1 ? 7 : weekday - 1
        
        var days: [Date?] = Array(repeating: nil, count: weekday - 1)
        
        var current = firstDay
        while current < interval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return days
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Semi-transparent overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Calendar card
            calendarCard
        }
        .onAppear {
            displayedMonth = selectedDate
        }
    }
    
    private var calendarCard: some View {
        VStack(spacing: 16) {
            monthNavigation
            weekdayHeaders
            daysGrid
        }
        .padding(16)
        .background(Color(hex: "1A1A1C"))
        .cornerRadius(16)
        .padding(.horizontal, 20)
        .padding(.top, 100)
    }
    
    private var monthNavigation: some View {
        HStack {
            Button(action: {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 36, height: 36)
            }
            
            Spacer()
            
            Text(monthString)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                if canGoForward {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(canGoForward ? .white : Color(hex: "3A3A3C"))
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 36, height: 36)
            }
            .disabled(!canGoForward)
        }
        .padding(.horizontal, 8)
    }
    
    private var weekdayHeaders: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .frame(height: 20)
            }
        }
    }
    
    private var daysGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                if let unwrappedDate = date {
                    CalendarDayButton(
                        date: unwrappedDate,
                        isSelected: calendar.isDate(unwrappedDate, inSameDayAs: selectedDate),
                        isCompleted: checkDayCompleted(unwrappedDate),
                        isToday: calendar.isDateInToday(unwrappedDate),
                        isFuture: unwrappedDate > Date()
                    ) {
                        if unwrappedDate <= Date() {
                            selectedDate = unwrappedDate
                            isPresented = false
                        }
                    }
                } else {
                    Color.clear
                        .frame(height: 36)
                }
            }
        }
    }
    
    private func checkDayCompleted(_ date: Date) -> Bool {
        healthManager.isDayCompleted(date)
    }
}

// MARK: - Calendar Day Button
struct CalendarDayButton: View {
    let date: Date
    let isSelected: Bool
    let isCompleted: Bool
    let isToday: Bool
    let isFuture: Bool
    let action: () -> Void
    
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Today ring
                if isToday {
                    Circle()
                        .stroke(Color(hex: "34C759"), lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
                
                // Selected fill
                if isSelected {
                    Circle()
                        .fill(Color(hex: "34C759"))
                        .frame(width: 36, height: 36)
                }
                
                Text(dayNumber)
                    .font(.system(size: 16, weight: isSelected || isToday ? .semibold : .regular))
                    .foregroundColor(
                        isFuture ? Color(hex: "3A3A3C") :
                        isSelected ? .black :
                        isCompleted ? Color(hex: "34C759") :
                        .white
                    )
            }
            .frame(width: 40, height: 40)
        }
        .disabled(isFuture)
    }
}

// MARK: - Circular Progress (Steps on top, Goal on bottom)
struct CircularProgressView: View {
    let steps: Int
    let goal: Int
    let progress: Double
    let percentage: String
    let goalReached: Bool
    
    var goalMultiplier: Int {
        guard goal > 0 else { return 0 }
        return steps / goal
    }
    
    var currentProgress: Double {
        guard goal > 0 else { return 0 }
        if goalMultiplier == 0 {
            return progress
        }
        let remainder = steps % goal
        return Double(remainder) / Double(goal)
    }
    
    private let circleSize: CGFloat = 280
    private let strokeWidth: CGFloat = 12
    
    var body: some View {
        ZStack {
            // Background fill
            Circle()
                .fill(Color(hex: "1A1A1C"))
                .frame(width: circleSize, height: circleSize)
            
            // Background stroke
            Circle()
                .stroke(Color(hex: "2C2C2E"), lineWidth: strokeWidth)
                .frame(width: circleSize, height: circleSize)
            
            // Main progress circle
            if goalMultiplier == 0 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(hex: "34C759"),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: progress)
            } else {
                Circle()
                    .stroke(Color(hex: "34C759"), lineWidth: strokeWidth)
                    .frame(width: circleSize, height: circleSize)
                
                if currentProgress > 0 {
                    Circle()
                        .trim(from: 0, to: currentProgress)
                        .stroke(
                            Color(hex: "34C759"),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: circleSize - 32, height: circleSize - 32)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1), value: currentProgress)
                }
            }
            
            // Top indicator - positioned at top edge of circle
            if goalReached {
                ZStack {
                    Circle()
                        .fill(Color(hex: "34C759"))
                        .frame(width: 26, height: 26)
                    
                    if goalMultiplier >= 2 {
                        Text("x\(goalMultiplier)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .offset(y: -circleSize/2 + strokeWidth + 28)
            }
            
            // Center content
            VStack(spacing: 2) {
                Text("Steps")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
                
                Text("\(steps.formatted())")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                
                Text("Goal \(goal.formatted())")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            
            // Bottom chevron - positioned at bottom edge of circle
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "8E8E93"))
                .offset(y: circleSize/2 - strokeWidth - 28)
        }
        .frame(width: circleSize, height: circleSize)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let percentage: String
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
                
                Spacer()
                
                Text(percentage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isPositive ? Color(hex: "34C759") : Color(hex: "FF3B30"))
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text(unit)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "1A1A1C"))
        .cornerRadius(16)
    }
}

// MARK: - Streak View
struct StreakView: View {
    let streakCount: Int
    let weekStreak: [Bool]
    let weekProgress: [Double]
    let currentDate: Date
    let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var selectedDayIndex: Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: currentDate)
        return (weekday == 1) ? 6 : weekday - 2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STREAK")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "8E8E93"))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(streakCount)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("days")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                }
                
                Spacer()
                
                // Fire icon when streak >= 1
                if streakCount >= 1 {
                    Text("🔥")
                        .font(.system(size: 40))
                }
            }
            
            HStack(spacing: 12) {
                ForEach(0..<7) { index in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "3A3A3C"))
                                .frame(width: 36, height: 36)
                            
                            if weekStreak[index] {
                                Circle()
                                    .fill(Color(hex: "34C759"))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            else if weekProgress[index] > 0 {
                                Circle()
                                    .trim(from: 0, to: weekProgress[index])
                                    .stroke(
                                        Color(hex: "34C759"),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .frame(width: 36, height: 36)
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        
                        Text(days[index])
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(index == selectedDayIndex ? .white : Color(hex: "8E8E93"))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "1A1A1C"))
        .cornerRadius(16)
    }
}

// MARK: - Bottom Navigation
struct BottomNavigationView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            TabButton(icon: "square.grid.2x2", title: "Main", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            Spacer()
            
            TabButton(icon: "trophy", title: "Top", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            Spacer()
            
            TabButton(icon: "gearshape", title: "Settings", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
        .background(Color(hex: "0A0A0A"))
    }
}

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : Color(hex: "8E8E93"))
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color(hex: "8E8E93"))
            }
        }
    }
}

// MARK: - Goal Editor (Consistent with onboarding)
struct GoalEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var goal: Int
    @State private var selectedGoal: Int = 10000
    @State private var customGoalText: String = ""
    @State private var showCustomInput: Bool = false
    @FocusState private var isCustomInputFocused: Bool
    
    let goalOptions = [5000, 10000, 15000]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                    .onTapGesture {
                        isCustomInputFocused = false
                    }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("Set your daily step goal")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.top, 40)
                            
                            // Goal options
                            VStack(spacing: 12) {
                                ForEach(goalOptions, id: \.self) { goalValue in
                                    Button(action: {
                                        isCustomInputFocused = false
                                        selectedGoal = goalValue
                                        showCustomInput = false
                                        customGoalText = ""
                                    }) {
                                        HStack {
                                            Text("\(goalValue.formatted()) steps")
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(selectedGoal == goalValue && !showCustomInput ? .black : .white)
                                            
                                            Spacer()
                                            
                                            if selectedGoal == goalValue && !showCustomInput {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .frame(height: 56)
                                        .background(selectedGoal == goalValue && !showCustomInput ? Color(hex: "34C759") : Color(hex: "1A1A1C"))
                                        .cornerRadius(12)
                                    }
                                }
                                
                                // Custom input
                                HStack {
                                    if showCustomInput {
                                        TextField("", text: $customGoalText, prompt: Text("Enter steps").foregroundColor(Color(hex: "8E8E93")))
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)
                                            .keyboardType(.numberPad)
                                            .focused($isCustomInputFocused)
                                            .onChange(of: customGoalText) { _, newValue in
                                                if let value = Int(newValue), value > 0 {
                                                    selectedGoal = value
                                                }
                                            }
                                    } else {
                                        Text("Custom goal")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    if showCustomInput {
                                        Button(action: {
                                            isCustomInputFocused = false
                                        }) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(hex: "34C759"))
                                        }
                                    } else {
                                        Image(systemName: "pencil")
                                            .foregroundColor(Color(hex: "8E8E93"))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .frame(height: 56)
                                .background(Color(hex: "1A1A1C"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(showCustomInput ? Color(hex: "34C759") : Color.clear, lineWidth: 2)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !showCustomInput {
                                        showCustomInput = true
                                        isCustomInputFocused = true
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            Spacer().frame(height: 40)
                            
                            // Save button
                            Button {
                                isCustomInputFocused = false
                                goal = selectedGoal
                                dismiss()
                            } label: {
                                Text("Save")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color(hex: "34C759"))
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                            .id("saveButton")
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: isCustomInputFocused) { _, focused in
                        if focused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    proxy.scrollTo("saveButton", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "34C759"))
                }
            }
        }
        .onAppear {
            selectedGoal = goal
            if !goalOptions.contains(goal) {
                showCustomInput = true
                customGoalText = "\(goal)"
            }
        }
    }
}

struct QuickGoalButton: View {
    let value: Int
    @Binding var currentGoal: String
    
    var body: some View {
        Button { currentGoal = "\(value)" } label: {
            Text("\(value)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(hex: "1A1A1C"))
                .cornerRadius(12)
        }
    }
}

// MARK: - Top Leaderboard View
struct TopLeaderboardView: View {
    @ObservedObject var leaderboardManager: LeaderboardManager
    @ObservedObject var authManager: AuthManager
    @ObservedObject var groupManager: GroupManager // NEW: Group Manager
    @State private var selectedUser: LeaderboardUser?
    @State private var showMyProfile = false
    @State private var selectedTab: GroupTab = .all // NEW: Track selected tab
    @State private var showGroupDetail: CustomGroup? = nil // NEW: For group detail sheet
    
    var canGoForward: Bool {
        let calendar = Calendar.current
        let tomorrow: Date
        
        if leaderboardManager.selectedPeriod == 0 {
            tomorrow = calendar.date(byAdding: .day, value: 1, to: leaderboardManager.selectedDate) ?? leaderboardManager.selectedDate
        } else if leaderboardManager.selectedPeriod == 1 {
            tomorrow = calendar.date(byAdding: .weekOfYear, value: 1, to: leaderboardManager.selectedDate) ?? leaderboardManager.selectedDate
        } else {
            tomorrow = calendar.date(byAdding: .month, value: 1, to: leaderboardManager.selectedDate) ?? leaderboardManager.selectedDate
        }
        
        return calendar.startOfDay(for: tomorrow) <= calendar.startOfDay(for: Date())
    }
    
    var dateString: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        
        if leaderboardManager.selectedPeriod == 0 {
            if calendar.isDateInToday(leaderboardManager.selectedDate) {
                return "TODAY"
            } else {
                formatter.dateFormat = "MMM d"
                return formatter.string(from: leaderboardManager.selectedDate).uppercased()
            }
        } else if leaderboardManager.selectedPeriod == 1 {
            formatter.dateFormat = "MMM d"
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: leaderboardManager.selectedDate))!
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))".uppercased()
        } else {
            formatter.dateFormat = "MMM"
            return formatter.string(from: leaderboardManager.selectedDate).uppercased()
        }
    }
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header - 32px from safe area
                HStack {
                    Text("Leaderboard")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Profile button
                    Button(action: {
                        showMyProfile = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "34C759"))
                                .frame(width: 40, height: 40)
                            
                            Text(String(authManager.userName.prefix(1).uppercased()))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                
                // First row: Date selector + Period selector - 32px below header
                HStack(spacing: 8) {
                    // Date selector - fixed width
                    HStack(spacing: 0) {
                        Button(action: { changeDate(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 28, height: 32)
                        }
                        
                        Text(dateString)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56)
                        
                        Button(action: { changeDate(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(canGoForward ? .white : Color(hex: "3A3A3C"))
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 28, height: 32)
                        }
                        .disabled(!canGoForward)
                    }
                    .frame(height: 32)
                    .background(Color(hex: "1A1A1C"))
                    .cornerRadius(8)
                    
                    // Period selector - fills remaining space
                    HStack(spacing: 0) {
                        ForEach(["DAY", "WEEK", "MONTH"], id: \.self) { period in
                            let index = period == "DAY" ? 0 : (period == "WEEK" ? 1 : 2)
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    leaderboardManager.selectedPeriod = index
                                    leaderboardManager.refresh()
                                }
                            }) {
                                Text(period)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(leaderboardManager.selectedPeriod == index ? .white : Color(hex: "8E8E93"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(
                                        leaderboardManager.selectedPeriod == index ?
                                        Color(hex: "3A3A3C") : Color.clear
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .background(Color(hex: "1A1A1C"))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                
                // NEW: Scrollable tabs - ALL | FRIENDS | Groups | +
                GroupTabSelector(
                    leaderboardManager: leaderboardManager,
                    groupManager: groupManager,
                    selectedTab: $selectedTab
                )
                .padding(.top, 16)
                
                // List content based on selected tab
                if leaderboardManager.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else {
                    switch selectedTab {
                    case .all:
                        if leaderboardManager.users.isEmpty {
                            emptyStateView(message: "No users yet")
                        } else {
                            LeaderboardList(leaderboardManager: leaderboardManager, onUserTap: { user in
                                selectedUser = user
                            })
                            .padding(.top, 32)
                        }
                        
                    case .friends:
                        if leaderboardManager.filteredUsers.isEmpty {
                            emptyStateView(message: "No friends yet", subtitle: "Add friends from the leaderboard")
                        } else {
                            ZStack(alignment: .bottomTrailing) {
                                LeaderboardList(leaderboardManager: leaderboardManager, onUserTap: { user in
                                    selectedUser = user
                                })
                                .padding(.top, 32)
                                
                                CompactInviteButton()
                                    .padding(.trailing, 20)
                                    .padding(.bottom, 100)
                            }
                        }
                        
                    case .group(let groupId):
                        if let group = groupManager.userGroups.first(where: { $0.id == groupId }) {
                            GroupLeaderboardView(
                                group: group,
                                groupManager: groupManager,
                                leaderboardManager: leaderboardManager,
                                onUserTap: { user in selectedUser = user },
                                onGroupTap: { showGroupDetail = group }
                            )
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedUser) { user in
            UserProfileView(user: user, leaderboardManager: leaderboardManager, authManager: authManager)
        }
        .sheet(isPresented: $showMyProfile) {
            MyProfileView(authManager: authManager, leaderboardManager: leaderboardManager)
        }
        .sheet(item: $showGroupDetail) { group in
            GroupDetailsSheet(group: group, groupManager: groupManager, leaderboardManager: leaderboardManager)
        }
        .onChange(of: selectedTab) { _, newTab in
            // Update leaderboardManager.showFriendsOnly based on tab
            switch newTab {
            case .all:
                leaderboardManager.showFriendsOnly = false
            case .friends:
                leaderboardManager.showFriendsOnly = true
            case .group:
                leaderboardManager.showFriendsOnly = false
            }
        }
    }
    
    @ViewBuilder
    func emptyStateView(message: String, subtitle: String? = nil) -> some View {
        Spacer()
        Text(message)
            .font(.system(size: 17))
            .foregroundColor(Color(hex: "8E8E93"))
        if let subtitle = subtitle {
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "8E8E93"))
                .padding(.top, 8)
        }
        Spacer()
    }
    
    func changeDate(by value: Int) {
        let calendar = Calendar.current
        let newDate: Date
        
        if leaderboardManager.selectedPeriod == 0 {
            newDate = calendar.date(byAdding: .day, value: value, to: leaderboardManager.selectedDate) ?? leaderboardManager.selectedDate
        } else if leaderboardManager.selectedPeriod == 1 {
            newDate = calendar.date(byAdding: .weekOfYear, value: value, to: leaderboardManager.selectedDate) ?? leaderboardManager.selectedDate
        } else {
            newDate = calendar.date(byAdding: .month, value: value, to: leaderboardManager.selectedDate) ?? leaderboardManager.selectedDate
        }
        
        if newDate <= Date() {
            withAnimation {
                leaderboardManager.selectedDate = newDate
                leaderboardManager.refresh()
            }
        }
    }
}

// MARK: - My Profile View
struct MyProfileView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var leaderboardManager: LeaderboardManager
    @Environment(\.dismiss) var dismiss
    
    var currentUser: LeaderboardUser? {
        leaderboardManager.users.first(where: { $0.id == leaderboardManager.currentUserID })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A")
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color(hex: "34C759"))
                            .frame(width: 100, height: 100)
                        
                        Text(String(authManager.userName.prefix(1).uppercased()))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .padding(.top, 40)
                    
                    // Name
                    Text(authManager.userName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Steps
                    VStack(spacing: 8) {
                        Text("\((currentUser?.steps ?? 0).formatted())")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("steps today")
                            .font(.system(size: 17))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "1A1A1C"))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // Stats
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("\(leaderboardManager.friends.count)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text("Friends")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "8E8E93"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                        
                        if let rank = leaderboardManager.getCurrentUserRank() {
                            VStack(spacing: 4) {
                                Text("#\(rank)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Rank")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "8E8E93"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "1A1A1C"))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "34C759"))
                }
            }
        }
    }
}

// MARK: - User Profile View
struct UserProfileView: View {
    let user: LeaderboardUser
    @ObservedObject var leaderboardManager: LeaderboardManager
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    var isCurrentUser: Bool {
        user.id == leaderboardManager.currentUserID
    }
    
    var isFriend: Bool {
        leaderboardManager.isFriend(userId: user.id)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A")
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color(hex: "34C759").opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Text(user.avatarLetter)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Color(hex: "34C759"))
                    }
                    .padding(.top, 40)
                    
                    // Name
                    Text(user.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Steps
                    VStack(spacing: 8) {
                        Text("\(user.steps.formatted())")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("steps today")
                            .font(.system(size: 17))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "1A1A1C"))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Action button
                    if !isCurrentUser {
                        Button {
                            if isFriend {
                                leaderboardManager.removeFriend(userId: user.id)
                            } else {
                                leaderboardManager.addFriend(userId: user.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: isFriend ? "person.badge.minus" : "person.badge.plus")
                                Text(isFriend ? "Remove Friend" : "Add Friend")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isFriend ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isFriend ? Color(hex: "FF3B30") : Color(hex: "34C759"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "34C759"))
                }
            }
        }
    }
}

// PreferenceKey для отслеживания позиции текущего пользователя
struct CurrentUserPositionKey: PreferenceKey {
    static var defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

struct LeaderboardList: View {
    @ObservedObject var leaderboardManager: LeaderboardManager
    var onUserTap: ((LeaderboardUser) -> Void)?
    @State private var currentUserRowPosition: CGFloat? = nil
    @State private var scrollViewHeight: CGFloat = 0
    @State private var stickyRowHeight: CGFloat = 68
    
    var currentUserRank: Int? {
        leaderboardManager.filteredUsers.firstIndex(where: { $0.id == leaderboardManager.currentUserID }).map { $0 + 1 }
    }
    
    var isCurrentUserVisible: Bool {
        guard let position = currentUserRowPosition else { return false }
        let bottomThreshold = scrollViewHeight - stickyRowHeight - 80
        return position >= 0 && position < bottomThreshold
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(leaderboardManager.filteredUsers.enumerated()), id: \.element.id) { index, user in
                            LeaderboardRow(
                                rank: index + 1,
                                user: user,
                                isCurrentUser: user.id == leaderboardManager.currentUserID
                            )
                            .onTapGesture {
                                onUserTap?(user)
                            }
                            .opacity(shouldHideInList(user: user) ? 0 : 1)
                            .background(
                                Group {
                                    if user.id == leaderboardManager.currentUserID {
                                        GeometryReader { rowGeometry in
                                            Color.clear.preference(
                                                key: CurrentUserPositionKey.self,
                                                value: rowGeometry.frame(in: .named("scrollView")).minY
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(CurrentUserPositionKey.self) { position in
                    currentUserRowPosition = position
                }
                
                if !isCurrentUserVisible, let rank = currentUserRank {
                    if let currentUser = leaderboardManager.filteredUsers.first(where: { $0.id == leaderboardManager.currentUserID }) {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(hex: "3A3A3C"))
                                .frame(height: 0.5)
                            
                            LeaderboardRow(
                                rank: rank,
                                user: currentUser,
                                isCurrentUser: true
                            )
                            .onTapGesture {
                                onUserTap?(currentUser)
                            }
                            .background(
                                GeometryReader { stickyGeometry in
                                    Color(hex: "0A0A0A")
                                        .onAppear {
                                            stickyRowHeight = stickyGeometry.size.height
                                        }
                                }
                            )
                        }
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.2), value: isCurrentUserVisible)
                    }
                }
            }
            .onAppear {
                scrollViewHeight = geometry.size.height
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                scrollViewHeight = newHeight
            }
        }
    }
    
    private func shouldHideInList(user: LeaderboardUser) -> Bool {
        return user.id == leaderboardManager.currentUserID && !isCurrentUserVisible
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let user: LeaderboardUser
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(rank)")
                .font(.system(size: 17, weight: isCurrentUser ? .bold : .semibold))
                .foregroundColor(isCurrentUser ? Color(hex: "34C759") : .white)
                .frame(width: 30, alignment: .leading)
            
            ZStack {
                Circle()
                    .fill(isCurrentUser ? Color(hex: "34C759") : Color(hex: "3A3A3C"))
                    .frame(width: 40, height: 40)
                
                Text(user.avatarLetter)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isCurrentUser ? .black : .white)
            }
            
            Text(user.name)
                .font(.system(size: 17, weight: isCurrentUser ? .semibold : .regular))
                .foregroundColor(.white)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(user.steps.formatted())")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("steps")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isCurrentUser ? Color(hex: "1A1A1C") : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
