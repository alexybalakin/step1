//
//  UIComponents.swift
//  Step1
//
//  Created by Alex Balakin on 1/19/26.
//

import SwiftUI
import AuthenticationServices
import UserNotifications

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

// MARK: - Onboarding Container (Multi-Step)
struct OnboardingView: View {
    @ObservedObject var healthManager: HealthManager
    @Binding var isOnboardingComplete: Bool
    let userID: String

    // Steps: "health", "motion", "goal", "complete"
    @State private var steps: [String] = []
    @State private var currentIndex: Int = 0
    @State private var isRequesting: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "000200")
                .ignoresSafeArea()

            if steps.isEmpty {
                // Loading — will compute steps in onAppear
                Color.clear
            } else if currentIndex < steps.count {
                let step = steps[currentIndex]
                Group {
                    switch step {
                    case "health":
                        OnboardingHealthAccessScreen {
                            guard !isRequesting else { return }
                            isRequesting = true
                            healthManager.requestHealthKitAuthorization { _ in
                                isRequesting = false
                                goToNext()
                            }
                        } onSkip: {
                            goToNext()
                        }
                    case "motion":
                        OnboardingMotionAccessScreen {
                            guard !isRequesting else { return }
                            isRequesting = true
                            healthManager.requestMotionPermission { _ in
                                isRequesting = false
                                goToNext()
                            }
                        } onSkip: {
                            goToNext()
                        }
                    case "goal":
                        OnboardingGoalScreen(healthManager: healthManager) {
                            goToNext()
                        }
                    case "complete":
                        OnboardingCompleteScreen {
                            UserDefaults.standard.set(true, forKey: "onboarding_\(userID)")
                            isOnboardingComplete = true
                        }
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
        .onAppear {
            buildSteps()
        }
    }

    private func buildSteps() {
        var result: [String] = []

        // Only show health screen if not yet authorized
        if !healthManager.isHealthKitAuthorized() {
            result.append("health")
        }

        // Only show motion screen if not yet authorized
        if !CMMotionPermissionHelper.isMotionAuthorized() {
            result.append("motion")
        }

        result.append("goal")
        result.append("complete")
        steps = result
    }

    private func goToNext() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex += 1
        }
    }
}

import CoreMotion

// Helper to check CoreMotion authorization status
enum CMMotionPermissionHelper {
    static func isMotionAuthorized() -> Bool {
        if #available(iOS 11.0, *) {
            return CMMotionActivityManager.authorizationStatus() == .authorized
        }
        return false
    }
}

// MARK: - Onboarding: Health Access Screen
struct OnboardingHealthAccessScreen: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "FF2D55"), Color(hex: "FF6482")], startPoint: .top, endPoint: .bottom)
                    )

                Text("Apple Health")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("We use Apple Health to accurately count your steps, distance, and activity. Your data stays private and never leaves your device.")
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onAllow) {
                    Text("Allow Access")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "34C759"))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Onboarding: Motion & Fitness Screen
struct OnboardingMotionAccessScreen: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "34C759"), Color(hex: "30D158")], startPoint: .top, endPoint: .bottom)
                    )

                Text("Motion & Fitness")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Motion & Fitness provides real-time step tracking directly from your iPhone's sensors. Steps update instantly as you walk.")
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onAllow) {
                    Text("Allow Access")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "34C759"))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Onboarding: Goal Selection Screen
struct OnboardingGoalScreen: View {
    @ObservedObject var healthManager: HealthManager
    let onContinue: () -> Void

    @State private var selectedGoal: Int = 10000
    @State private var customGoalText: String = ""
    @State private var showCustomInput: Bool = false
    @FocusState private var isCustomInputFocused: Bool

    let goalOptions = [5000, 10000, 15000]

    var body: some View {
        ZStack {
            Color(hex: "000200")
                .ignoresSafeArea()
                .onTapGesture { isCustomInputFocused = false }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 60)

                        VStack(spacing: 16) {
                            Image(systemName: "target")
                                .font(.system(size: 60))
                                .foregroundColor(Color(hex: "34C759"))

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
                                            .foregroundColor(.white)
                                        Spacer()
                                        if selectedGoal == goal && !showCustomInput {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(Color(hex: "34C759"))
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .frame(height: 56)
                                    .background(Color(hex: "1A1A1C"))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedGoal == goal && !showCustomInput ? Color(hex: "34C759") : Color.clear, lineWidth: 1.5)
                                    )
                                }
                            }

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
                                    Button(action: { isCustomInputFocused = false }) {
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

                        Button {
                            isCustomInputFocused = false
                            healthManager.dailyGoal = selectedGoal
                            healthManager.saveDailyGoal()
                            onContinue()
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
                            withAnimation { proxy.scrollTo("continueButton", anchor: .bottom) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Onboarding: Complete Screen
struct OnboardingCompleteScreen: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: "34C759"))

                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Start walking and track your progress. You can change your goal and permissions anytime in Settings.")
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button(action: onStart) {
                Text("Start")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "34C759"))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
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
                    // Sign in with Apple (custom button for consistent font)
                    Button(action: {
                        authManager.signInWithApple()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 17, weight: .medium))
                            Text("Sign up with Apple")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading)
                    .opacity(authManager.isLoading ? 0.6 : 1)
                    
                    // Sign in with Google
                    Button(action: {
                        authManager.signInWithGoogle()
                    }) {
                        HStack(spacing: 8) {
                            // Google colored logo
                            GoogleLogo()
                                .frame(width: 17, height: 17)
                            Text("Sign up with Google")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading)
                    .opacity(authManager.isLoading ? 0.6 : 1)
                    
                    // Sign up with Email
                    Button(action: {
                        showEmailRegister = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 15))
                            Text("Sign up with Email")
                                .font(.system(size: 16, weight: .medium))
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
                            .font(.system(size: 16, weight: .medium))
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
                    // Sign in link
                    Button(action: {
                        showEmailLogin = true
                    }) {
                        Text("Already have an account? ")
                            .foregroundColor(Color(hex: "8E8E93"))
                        + Text("Sign In")
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

// MARK: - Google Logo (from Assets)
struct GoogleLogo: View {
    var body: some View {
        Image("google_logo")
            .resizable()
            .scaledToFit()
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
    @State private var showProfile = false
    @State private var notificationsEnabled = false
    @State private var dailyReminderTime = Date()
    @State private var morningNotificationEnabled = false
    @State private var goalNotificationEnabled = true
    @State private var streakNotificationEnabled = false
    @State private var useMetric = true
    @State private var weekStartsMonday = true
    @State private var showShareSheet = false
    @State private var hideZeroStepsUsers = true
    @State private var hideLeaderboard = false

    let appStoreLink = "https://apps.apple.com/rs/app/steplease-step-tracker/id6758054873"
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // No title - removed per request
                    Spacer().frame(height: 16)
                    
                    // Account
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "ACCOUNT")
                        
                        VStack(spacing: 0) {
                            Button(action: { showProfile = true }) {
                                SettingsRowContent(
                                    icon: "person.circle.fill",
                                    title: "Profile",
                                    value: authManager.userName.isEmpty ? "User" : authManager.userName,
                                    showChevron: true
                                )
                            }
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    // Goals
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

                    // Leaderboard
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "LEADERBOARD")

                        VStack(spacing: 0) {
                            // Hide 0 steps users
                            HStack {
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: "8E8E93"))
                                    .cornerRadius(6)

                                Text("Hide 0 Steps Users")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)

                                Spacer()

                                Toggle("", isOn: $hideZeroStepsUsers)
                                    .labelsHidden()
                                    .tint(Color(hex: "00CA48"))
                                    .fixedSize()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider()
                                .background(Color(hex: "3A3A3C"))
                                .padding(.leading, 52)

                            // Hide Leaderboard
                            HStack {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: "FF3B30"))
                                    .cornerRadius(6)

                                Text("Hide Leaderboard")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)

                                Spacer()

                                Toggle("", isOn: $hideLeaderboard)
                                    .labelsHidden()
                                    .tint(Color(hex: "00CA48"))
                                    .fixedSize()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .onChange(of: hideZeroStepsUsers) { _, value in
                        UserDefaults.standard.set(value, forKey: "hide_zero_steps_users")
                    }
                    .onChange(of: hideLeaderboard) { _, value in
                        UserDefaults.standard.set(value, forKey: "hide_leaderboard")
                    }

                    // General
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "GENERAL")
                        
                        VStack(spacing: 0) {
                            // Distance units
                            HStack {
                                Image(systemName: "ruler")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: "007AFF"))
                                    .cornerRadius(6)
                                
                                Text("Distance")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Picker("", selection: $useMetric) {
                                    Text("km").tag(true)
                                    Text("mi").tag(false)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            Divider()
                                .background(Color(hex: "3A3A3C"))
                                .padding(.leading, 52)
                            
                            // First day of week
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: "34C759"))
                                    .cornerRadius(6)
                                
                                Text("Week starts")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Picker("", selection: $weekStartsMonday) {
                                    Text("Mon").tag(true)
                                    Text("Sun").tag(false)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .onChange(of: useMetric) { _, value in
                        UserDefaults.standard.set(value, forKey: "use_metric")
                        healthManager.useMetric = value
                    }
                    .onChange(of: weekStartsMonday) { _, value in
                        UserDefaults.standard.set(value, forKey: "week_starts_monday")
                        healthManager.weekStartsMonday = value
                    }
                    
                    // Notifications
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "NOTIFICATIONS")
                        
                        VStack(spacing: 0) {
                            // Daily Reminder
                            HStack {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: "FF9500"))
                                    .cornerRadius(6)
                                
                                Text("Daily Reminder")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Toggle("", isOn: $notificationsEnabled)
                                    .labelsHidden()
                                    .tint(Color(hex: "00CA48"))
                                    .fixedSize()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            
                            if notificationsEnabled {
                                Divider()
                                    .background(Color(hex: "3A3A3C"))
                                    .padding(.leading, 52)
                                
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color(hex: "5856D6"))
                                        .cornerRadius(6)
                                    
                                    Text("Reminder Time")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    DatePicker("", selection: $dailyReminderTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            
                            Divider()
                                .background(Color(hex: "3A3A3C"))
                                .padding(.leading, 52)
                            
                            // Morning motivation
                            HStack {
                                Image(systemName: "sunrise.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: "FFCC00"))
                                    .cornerRadius(6)
                                
                                Text("Morning Motivation")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Toggle("", isOn: $morningNotificationEnabled)
                                    .labelsHidden()
                                    .tint(Color(hex: "00CA48"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            Divider()
                                .background(Color(hex: "3A3A3C"))
                                .padding(.leading, 52)
                            
                            // Goal achieved
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: "34C759"))
                                    .cornerRadius(6)
                                
                                Text("Goal Achieved")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Toggle("", isOn: $goalNotificationEnabled)
                                    .labelsHidden()
                                    .tint(Color(hex: "00CA48"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            Divider()
                                .background(Color(hex: "3A3A3C"))
                                .padding(.leading, 52)
                            
                            // Streak reminder
                            HStack {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: "FF3B30"))
                                    .cornerRadius(6)
                                
                                Text("Streak Reminder")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Toggle("", isOn: $streakNotificationEnabled)
                                    .labelsHidden()
                                    .tint(Color(hex: "00CA48"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled {
                            NotificationManager.shared.requestPermission { granted in
                                if granted {
                                    NotificationManager.shared.scheduleDailyReminder(at: dailyReminderTime)
                                    NotificationManager.shared.scheduleGoalAchievedCheck(goal: healthManager.dailyGoal)
                                } else {
                                    notificationsEnabled = false
                                }
                            }
                        } else {
                            NotificationManager.shared.removeAllNotifications()
                        }
                        UserDefaults.standard.set(enabled, forKey: "notifications_enabled")
                    }
                    .onChange(of: dailyReminderTime) { _, newTime in
                        if notificationsEnabled {
                            NotificationManager.shared.scheduleDailyReminder(at: newTime)
                        }
                        UserDefaults.standard.set(newTime.timeIntervalSince1970, forKey: "reminder_time")
                    }
                    
                    // Widget
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "WIDGET")
                        
                        VStack(spacing: 0) {
                            Button(action: {
                                // Open iOS widget gallery instruction
                                if let url = URL(string: "https://support.apple.com/en-us/HT207122") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "square.grid.2x2.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color(hex: "00CA48"))
                                        .cornerRadius(6)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Add Widget")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                        
                                        Text("Long press home screen → Add Widget → StePlease")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "8E8E93"))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(hex: "48484A"))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    // Links section (combined News & Support)
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "LINKS")
                        
                        VStack(spacing: 0) {
                            // Invite Friends - first item
                            Button(action: { showShareSheet = true }) {
                                SettingsRowContent(
                                    icon: "person.2.fill",
                                    title: "Invite Friends",
                                    value: "",
                                    showChevron: true
                                )
                            }
                            
                            Divider()
                                .background(Color(hex: "3A3A3C"))
                                .padding(.leading, 52)
                            
                            // Telegram Channel
                            Button(action: {
                                if let url = URL(string: "https://t.me/steplease") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                SettingsRowContent(
                                    icon: "paperplane.fill",
                                    title: "Telegram Channel",
                                    value: "",
                                    showChevron: true
                                )
                            }
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)
                    }
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
                        .frame(height: 100)
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
        .onAppear {
            notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
            let savedTime = UserDefaults.standard.double(forKey: "reminder_time")
            if savedTime > 0 {
                dailyReminderTime = Date(timeIntervalSince1970: savedTime)
            } else {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = 21
                components.minute = 0
                dailyReminderTime = Calendar.current.date(from: components) ?? Date()
            }
            if UserDefaults.standard.object(forKey: "use_metric") != nil {
                useMetric = UserDefaults.standard.bool(forKey: "use_metric")
            }
            if UserDefaults.standard.object(forKey: "week_starts_monday") != nil {
                weekStartsMonday = UserDefaults.standard.bool(forKey: "week_starts_monday")
            }
            hideZeroStepsUsers = UserDefaults.standard.object(forKey: "hide_zero_steps_users") == nil ? true : UserDefaults.standard.bool(forKey: "hide_zero_steps_users")
            hideLeaderboard = UserDefaults.standard.bool(forKey: "hide_leaderboard")
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(authManager: authManager, healthManager: healthManager)
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorView(goal: $healthManager.dailyGoal)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Join me on StePlease! Track your steps and compete with friends! \(appStoreLink)"])
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var authManager: AuthManager
    @ObservedObject var healthManager: HealthManager
    @State private var showNameEditor = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color(hex: "00CA48"))
                                .frame(width: 80, height: 80)
                            
                            Text(String(authManager.userName.prefix(1)).uppercased())
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 24)
                        
                        VStack(spacing: 4) {
                            Text(authManager.userName.isEmpty ? "User" : authManager.userName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            
                            if !authManager.userEmail.isEmpty {
                                Text(authManager.userEmail)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "8E8E93"))
                            }
                            
                            Text("Auth: \(authManager.authProvider.capitalized)")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(Color(hex: "8E8E93"))
                                .padding(.top, 2)
                        }
                        
                        // Edit name
                        VStack(spacing: 0) {
                            Button(action: { showNameEditor = true }) {
                                SettingsRowContent(
                                    icon: "pencil",
                                    title: "Edit Name",
                                    value: authManager.userName,
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
                        .padding(.horizontal, 20)
                        
                        Spacer()
                            .frame(height: 40)
                        
                        // Permissions
                        VStack(spacing: 0) {
                            SettingsSectionHeader(title: "PERMISSIONS")

                            VStack(spacing: 0) {
                                NavigationLink(destination: AppleHealthSettingsView(healthManager: healthManager)) {
                                    SettingsRowContent(
                                        icon: "heart.text.square.fill",
                                        title: "Apple Health",
                                        value: healthManager.healthKitConnected ? "Connected" : "Not connected",
                                        showChevron: true
                                    )
                                }

                                Divider()
                                    .background(Color(hex: "3A3A3C"))
                                    .padding(.leading, 52)

                                Button(action: {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    SettingsRowContent(
                                        icon: "figure.walk.motion",
                                        title: "Motion & Fitness",
                                        value: CMMotionPermissionHelper.isMotionAuthorized() ? "Allowed" : "Not set",
                                        showChevron: true
                                    )
                                }

                                Divider()
                                    .background(Color(hex: "3A3A3C"))
                                    .padding(.leading, 52)

                                Button(action: {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    SettingsRowContent(
                                        icon: "gear",
                                        title: "Open System Settings",
                                        value: "",
                                        showChevron: true
                                    )
                                }
                            }
                            .background(Color(hex: "1A1A1C"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 16)

                        // Sign Out & Delete
                        VStack(spacing: 12) {
                            Button(action: {
                                authManager.signOut()
                                dismiss()
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
                        .padding(.bottom, 40)
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "00CA48"))
                }
            }
        }
        .sheet(isPresented: $showNameEditor) {
            NameEditorView(authManager: authManager)
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                isDeleting = true
                authManager.deleteAccount { error in
                    isDeleting = false
                    if let error = error {
                        deleteError = error
                    } else {
                        dismiss()
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
    @State private var nameError: String?
    @State private var isChecking = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Change your name")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    
                    VStack(spacing: 8) {
                        TextField("Name", text: $newName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(height: 60)
                            .background(Color(hex: "1A1A1C"))
                            .cornerRadius(12)
                            .padding(.horizontal, 40)
                            .onChange(of: newName) { _, _ in
                                nameError = nil
                            }
                        
                        if let error = nameError {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 1, green: 0.27, blue: 0.23))
                                .padding(.horizontal, 40)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        let trimmed = newName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        
                        // FIX #1: Check uniqueness before saving
                        isChecking = true
                        nameError = nil
                        authManager.checkNameUniqueness(name: trimmed, forUserID: authManager.userID) { uniqueName in
                            DispatchQueue.main.async {
                                isChecking = false
                                if uniqueName != trimmed {
                                    // Name was taken
                                    nameError = "This name is already taken"
                                } else {
                                    authManager.saveUserNameToFirestore(trimmed)
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isChecking {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text("Save")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: "34C759"))
                        .cornerRadius(12)
                    }
                    .disabled(isChecking)
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
    let appStoreLink = "https://apps.apple.com/rs/app/steplease-step-tracker/id6758054873" // Update with real link after release
    
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
    let appStoreLink = "https://apps.apple.com/rs/app/steplease-step-tracker/id6758054873"
    
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
    var subtitle: String? = nil
    let value: String
    let showChevron: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "34C759"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }

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
    var authManager: AuthManager? = nil
    var onProfileTap: (() -> Void)? = nil
    var onMenuTap: (() -> Void)? = nil  // Menu callback
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
            // Left - Profile button
            Button(action: {
                onProfileTap?()  // FIX #8: Navigate to profile
            }) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "0A0A0A").opacity(0.95))
                    
                    if let auth = authManager, !auth.isAnonymous, !auth.userName.isEmpty {
                        Circle()
                            .fill(Color(hex: "34C759"))
                        
                        Text(String(auth.userName.prefix(1)).uppercased())
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                    } else {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.25), location: 0),
                                        .init(color: Color.white.opacity(0.1), location: 0.5),
                                        .init(color: Color.white.opacity(0.02), location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                        
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // Center - D/W/M period switcher
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    let labels = ["D", "W", "M"]
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = index
                        }
                    }) {
                        ZStack {
                            if selectedPeriod == index {
                                Circle()
                                    .fill(Color(hex: "1A1A1A"))
                                    .frame(width: 36, height: 36)
                            }
                            
                            Text(labels[index])
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(selectedPeriod == index ? .white : Color(hex: "8E8E93"))
                        }
                        .frame(width: 36, height: 36)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    Capsule()
                        .fill(Color(hex: "0A0A0A").opacity(0.95))
                    
                    Capsule()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.25), location: 0),
                                    .init(color: Color.white.opacity(0.1), location: 0.5),
                                    .init(color: Color.white.opacity(0.02), location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            )
            .frame(height: 44)
            
            Spacer()
            
            // Right - Options button (menu)
            Button(action: {
                onMenuTap?()
            }) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "0A0A0A").opacity(0.95))
                    
                    Circle()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.25), location: 0),
                                    .init(color: Color.white.opacity(0.1), location: 0.5),
                                    .init(color: Color.white.opacity(0.02), location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
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
    
    var calendar: Calendar {
        healthManager.appCalendar
    }
    
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var weekdays: [String] {
        if healthManager.weekStartsMonday {
            return ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
        } else {
            return ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        }
    }
    
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
        let firstWeekday = calendar.firstWeekday
        var offset = weekday - firstWeekday
        if offset < 0 { offset += 7 }
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        var current = firstDay
        while current < interval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return days
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            calendarCard
        }
        .onAppear {
            displayedMonth = selectedDate
            healthManager.fetchMonthProgress(for: displayedMonth)
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
                healthManager.fetchMonthProgress(for: displayedMonth)
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
                    healthManager.fetchMonthProgress(for: displayedMonth)
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
                        progress: healthManager.progressForDate(unwrappedDate),
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
                        .frame(height: 40)
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
    let progress: Double  // 0.0 to 1.0+
    let isToday: Bool
    let isFuture: Bool
    let action: () -> Void
    
    var isCompleted: Bool { progress >= 1.0 }
    
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isFuture {
                    // Future — no ring, dim text
                    Text(dayNumber)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(hex: "3A3A3C"))
                } else if isSelected {
                    // Selected day — green filled circle
                    Circle()
                        .fill(Color(hex: "34C759"))
                        .frame(width: 36, height: 36)
                    
                    Text(dayNumber)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                } else if isCompleted {
                    // Goal reached — green filled circle
                    Circle()
                        .fill(Color(hex: "34C759"))
                        .frame(width: 36, height: 36)
                    
                    Text(dayNumber)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                } else if progress > 0 {
                    // Partial progress — ring showing how much done
                    ZStack {
                        // Background ring (track)
                        Circle()
                            .stroke(Color(hex: "2A2A2C"), lineWidth: 3)
                            .frame(width: 36, height: 36)
                        
                        // Progress ring
                        Circle()
                            .trim(from: 0, to: min(progress, 1.0))
                            .stroke(
                                Color(hex: "34C759").opacity(0.7),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                        
                        Text(dayNumber)
                            .font(.system(size: 15, weight: isToday ? .semibold : .regular))
                            .foregroundColor(.white)
                    }
                } else {
                    // No steps — plain
                    if isToday {
                        Circle()
                            .stroke(Color(hex: "3A3A3C"), lineWidth: 2)
                            .frame(width: 36, height: 36)
                    }
                    
                    Text(dayNumber)
                        .font(.system(size: 15, weight: isToday ? .semibold : .regular))
                        .foregroundColor(isToday ? .white : Color(hex: "8E8E93"))
                }
                
                // Today indicator dot
                if isToday && !isSelected {
                    Circle()
                        .fill(Color(hex: "34C759"))
                        .frame(width: 4, height: 4)
                        .offset(y: 16)
                }
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
    let dateLabel: String
    let isToday: Bool
    let onGoBack: () -> Void      // go to older day
    let onGoForward: () -> Void   // go to newer day
    let canGoBack: Bool           // can go further into past (max 7 days)
    let canGoForward: Bool        // can go to newer day (false if today)
    var onJumpToToday: (() -> Void)? = nil  // FIX #5: Jump directly to today
    
    @State private var dragOffset: CGFloat = 0
    @State private var swipeDirection: Int = 0
    
    var goalMultiplier: Int {
        guard goal > 0 else { return 0 }
        return steps / goal
    }
    
    // FIX #3: Progress for inner circle shows progress toward next goal multiplier
    var currentProgress: Double {
        guard goal > 0 else { return 0 }
        if goalMultiplier == 0 { return 0 }  // No inner circle before first goal
        let stepsOverGoal = steps - goal  // Steps beyond first goal
        let progressToNext = Double(stepsOverGoal % goal) / Double(goal)
        return progressToNext
    }
    
    private let containerSize: CGFloat = 280
    private let circleSize: CGFloat = 270
    private let strokeWidth: CGFloat = 10
    private let innerCircleSize: CGFloat = 250
    private let innerStrokeWidth: CGFloat = 2
    
    var body: some View {
        HStack(spacing: 24) {
            // Left dot — dim if can't go further back
            Circle()
                .fill(Color(hex: canGoBack ? "B8B8B8" : "1F1F1F"))
                .frame(width: 8, height: 8)
                .onTapGesture {
                    if canGoBack {
                        swipeDirection = -1
                        withAnimation(.easeInOut(duration: 0.3)) { onGoBack() }
                    }
                }
            
            // Main circle
            ZStack {
                Circle()
                    .fill(Color(hex: "101010"))
                    .frame(width: containerSize, height: containerSize)
                
                Circle()
                    .stroke(Color(hex: "1A1A1A"), lineWidth: strokeWidth)
                    .frame(width: circleSize, height: circleSize)
                
                if goalMultiplier == 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color(hex: "00CA48"),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: circleSize, height: circleSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1), value: progress)
                } else {
                    Circle()
                        .stroke(Color(hex: "00CA48"), lineWidth: strokeWidth)
                        .frame(width: circleSize, height: circleSize)
                    
                    if currentProgress > 0 {
                        Circle()
                            .trim(from: 0, to: currentProgress)
                            .stroke(
                                Color(hex: "00CA48"),
                                style: StrokeStyle(lineWidth: innerStrokeWidth, lineCap: .round)
                            )
                            .frame(width: innerCircleSize, height: innerCircleSize)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1), value: currentProgress)
                    }
                }
                
                VStack(spacing: 16) {
                    ZStack {
                        if goalReached {
                            Circle()
                                .fill(Color(hex: "00CA48"))
                                .frame(width: 28, height: 28)
                            
                            if goalMultiplier >= 2 {
                                Text("\(goalMultiplier)X")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .contentTransition(.numericText())
                                    .animation(.easeOut(duration: 0.4), value: goalMultiplier)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .frame(width: 34, height: 34)
                    
                    Text(dateLabel)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(goalReached ? Color(hex: "00CA48") : Color(hex: "8E8E93"))
                        .contentTransition(.interpolate)
                        .animation(.easeOut(duration: 0.3), value: dateLabel)

                    Text("\(steps.formatted())")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.easeOut(duration: 0.6), value: steps)

                    Text("Goal \(goal.formatted())")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.4), value: goal)

                    ZStack {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    .frame(width: 34, height: 34)
                }
            }
            .frame(width: containerSize, height: containerSize)
            .clipShape(Circle())
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        let t = value.translation.width
                        // Swipe right = go back (older), swipe left = go forward (newer)
                        if t > 0 && canGoBack {
                            dragOffset = t * 0.3
                        } else if t < 0 && canGoForward {
                            dragOffset = t * 0.3
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                        // Swipe right (finger moves right) = go to older day
                        if value.translation.width > threshold && canGoBack {
                            swipeDirection = -1
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onGoBack()
                            }
                        }
                        // Swipe left (finger moves left) = go to newer day
                        else if value.translation.width < -threshold && canGoForward {
                            swipeDirection = 1
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onGoForward()
                            }
                        }
                    }
            )
            
            // Right dot — dim if today (can't go forward)
            Circle()
                .fill(Color(hex: canGoForward ? "B8B8B8" : "1F1F1F"))
                .frame(width: 8, height: 8)
                .onTapGesture {
                    if canGoForward {
                        swipeDirection = 1
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onGoForward()
                        }
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .overlay(alignment: .topTrailing) {
            // Today button — positioned at top right, 16px from screen edge
            if !isToday {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onJumpToToday?() ?? onGoForward()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "8E8E93"))
                        Text("Today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "1C1C1E"))
                    .cornerRadius(14)
                }
                .padding(.top, 24)
            }
        }
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
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.5), value: value)

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

// MARK: - Streak Tile
struct StreakTile: View {
    let currentStreak: Int
    let maxStreak: Int
    @Binding var showPopup: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with chevron
            HStack(spacing: 10) {
                Text("Streak")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(hex: "8E8E93"))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            // Current streak value
            HStack(spacing: 2) {
                Text("\(currentStreak)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(currentStreak > 0 ? .white : Color(hex: "8E8E93"))
                Text(" 🔥")
                    .font(.system(size: 16))
                    .opacity(currentStreak > 0 ? 1.0 : 0.5)
            }

            // Max streak
            Text("MAX \(maxStreak)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "121212"))
        .cornerRadius(20)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.25)) { showPopup = true }
        }
    }
}

// MARK: - Streak Popup (Bottom Sheet)
struct StreakPopup: View {
    let currentStreak: Int
    let maxStreak: Int
    @Binding var isPresented: Bool
    @State private var sheetOffset: CGFloat = 500

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background
            Color.black.opacity(0.70)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Bottom sheet
            VStack(spacing: 16) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "3A3A3C"))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                // Header with close button
                HStack {
                    Text("Streak")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .frame(width: 30, height: 30)
                            .background(Color(hex: "1C1C1E"))
                            .clipShape(Circle())
                    }
                }

                // Stats
                HStack(spacing: 12) {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("\(currentStreak)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                            Text("🔥")
                                .font(.system(size: 30))
                        }
                        Text("Current Streak")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "1C1C1E"))
                    .cornerRadius(14)

                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("\(maxStreak)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                            Text("🏆")
                                .font(.system(size: 30))
                        }
                        Text("Best Streak")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "1C1C1E"))
                    .cornerRadius(14)
                }

                // Explanation
                VStack(alignment: .leading, spacing: 10) {
                    Text("How Streaks Work")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("A streak counts consecutive days where you've reached your daily step goal. Each day you hit your target, your streak grows by one. Missing a day resets it to zero.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "1C1C1E"))
                .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "161618"))
                    .ignoresSafeArea(edges: .bottom)
            )
            .offset(y: sheetOffset)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                sheetOffset = 0
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            sheetOffset = 500
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// MARK: - Goal Celebration Popup
struct GoalCelebrationView: View {
    let steps: Int
    let goal: Int
    @Binding var isPresented: Bool
    @State private var showConfetti = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var textOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background 80% opacity
            Color.black.opacity(0.80)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 24) {
                // Animated checkmark circle
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Color(hex: "00CA48").opacity(0.2))
                        .frame(width: 140, height: 140)
                        .scaleEffect(showConfetti ? 1.2 : 0.8)
                        .opacity(showConfetti ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: showConfetti)
                    
                    // Main circle
                    Circle()
                        .fill(Color(hex: "00CA48"))
                        .frame(width: 100, height: 100)
                        .scaleEffect(checkmarkScale)
                    
                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.black)
                        .scaleEffect(checkmarkScale)
                }
                
                VStack(spacing: 12) {
                    Text("Goal Reached! 🎉")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(steps.formatted()) steps")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "00CA48"))
                    
                    Text("You've crushed your \(goal.formatted()) step goal!")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .multilineTextAlignment(.center)
                }
                .opacity(textOpacity)
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
                    Text("Yeah!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "00CA48"))
                        .cornerRadius(14)
                }
                .padding(.horizontal, 40)
                .opacity(textOpacity)
            }
            .padding(32)
        }
        .onAppear {
            // Animate checkmark
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
            }
            // Animate text
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                textOpacity = 1.0
            }
            // Start confetti pulse
            showConfetti = true
        }
    }
}

// MARK: - Best Day Tile
struct BestDayTile: View {
    let bestSteps: Int
    let bestDate: Date?
    @Binding var showPopup: Bool
    
    private var dateString: String {
        guard let date = bestDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with chevron
            HStack(spacing: 10) {
                Text("Best Day")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(hex: "8E8E93"))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            
            // Best steps value
            Text("\(bestSteps.formatted())")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            // Date of best day
            Text(dateString)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "121212"))
        .cornerRadius(20)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.25)) { showPopup = true }
        }
    }
}

// MARK: - Best Day Popup
struct BestDayPopup: View {
    let bestSteps: Int
    let bestDate: Date?
    @Binding var isPresented: Bool
    @State private var sheetOffset: CGFloat = 500

    private var dateString: String {
        guard let date = bestDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }

    private var daysAgo: String {
        guard let date = bestDate else { return "" }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background
            Color.black.opacity(0.70)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Bottom sheet
            VStack(spacing: 16) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "3A3A3C"))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                // Header with close button
                HStack {
                    Text("Best Day")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .frame(width: 30, height: 30)
                            .background(Color(hex: "1C1C1E"))
                            .clipShape(Circle())
                    }
                }

                // Main stat
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text("\(bestSteps.formatted())")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                        Text("👑")
                            .font(.system(size: 30))
                    }

                    Text("steps")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "1C1C1E"))
                .cornerRadius(14)

                // Date info
                VStack(spacing: 6) {
                    Text(dateString)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(daysAgo)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "1C1C1E"))
                .cornerRadius(14)

                // Explanation
                VStack(alignment: .leading, spacing: 10) {
                    Text("About Best Day")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("This is your personal record — the highest number of steps you've taken in a single day. Keep challenging yourself to beat it!")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "1C1C1E"))
                .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "161618"))
                    .ignoresSafeArea(edges: .bottom)
            )
            .offset(y: sheetOffset)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                sheetOffset = 0
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            sheetOffset = 500
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// MARK: - Apple Health Settings View
struct AppleHealthSettingsView: View {
    @ObservedObject var healthManager: HealthManager
    @Environment(\.dismiss) var dismiss
    @State private var syncEnabled: Bool = true
    @State private var isFetching = false
    @State private var lastFetchTime: String = "Never"

    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                    // Sync with Apple Health
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "SYNC WITH APPLE HEALTH")

                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: "34C759"))
                                    .cornerRadius(6)

                                Text("Steps")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)

                                Spacer()

                                Toggle("", isOn: $syncEnabled)
                                    .labelsHidden()
                                    .tint(Color(hex: "00CA48"))
                                    .fixedSize()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)

                        Text("StePlease syncs step data from Apple Health. Your data stays private and never leaves your device.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)

                    // Fetch
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "DATA")

                        VStack(spacing: 0) {
                            Button(action: {
                                fetchNow()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color(hex: "007AFF"))
                                        .cornerRadius(6)

                                    Text("Fetch Now")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)

                                    Spacer()

                                    if isFetching {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .disabled(isFetching)
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)

                        Text("Last Fetch: \(lastFetchTime)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)

                    // Status
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "STATUS")

                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: "heart.text.square.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "FF2D55"))
                                    .frame(width: 28)

                                Text("Apple Health")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)

                                Spacer()

                                Text(healthManager.healthKitConnected ? "Connected" : "Not connected")
                                    .font(.system(size: 15))
                                    .foregroundColor(healthManager.healthKitConnected ? Color(hex: "34C759") : Color(hex: "FF3B30"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            if !healthManager.healthKitConnected {
                                Divider()
                                    .background(Color(hex: "3A3A3C"))
                                    .padding(.leading, 52)

                                Button(action: {
                                    healthManager.requestHealthKitAuthorization()
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Color(hex: "34C759"))
                                            .frame(width: 28)

                                        Text("Connect Apple Health")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "34C759"))

                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .background(Color(hex: "1A1A1C"))
                        .cornerRadius(12)

                        if !healthManager.healthKitConnected {
                            Text("To enable, go to Settings → Health → Data Access & Devices → Sources → StePlease")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "8E8E93"))
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 100)
                }
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            syncEnabled = UserDefaults.standard.object(forKey: "healthKitSyncEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "healthKitSyncEnabled")
            healthManager.verifyHealthKitAccess()
            updateLastFetchTime()
            // Auto-sync on screen appear
            if syncEnabled && healthManager.healthKitConnected {
                fetchNow()
            }
        }
        .onChange(of: syncEnabled) { _, enabled in
            UserDefaults.standard.set(enabled, forKey: "healthKitSyncEnabled")
            if enabled && healthManager.healthKitConnected {
                fetchNow()
            }
        }
    }

    private func fetchNow() {
        isFetching = true
        healthManager.loadDataForCurrentDate()
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastHealthFetchTime")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isFetching = false
            updateLastFetchTime()
        }
    }

    private func updateLastFetchTime() {
        let timestamp = UserDefaults.standard.double(forKey: "lastHealthFetchTime")
        if timestamp > 0 {
            let date = Date(timeIntervalSince1970: timestamp)
            let elapsed = Date().timeIntervalSince(date)
            if elapsed < 60 {
                lastFetchTime = "Just now"
            } else if elapsed < 3600 {
                let mins = Int(elapsed / 60)
                lastFetchTime = "\(mins) min ago"
            } else if elapsed < 86400 {
                let hours = Int(elapsed / 3600)
                lastFetchTime = "\(hours) hour\(hours > 1 ? "s" : "") ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "d MMM, HH:mm"
                lastFetchTime = formatter.string(from: date)
            }
        } else {
            lastFetchTime = "Never"
        }
    }
}

// MARK: - Health Disconnected Popup (Bottom Sheet)
struct HealthDisconnectedPopup: View {
    @Binding var isPresented: Bool
    @State private var showInstructions = false
    @State private var sheetOffset: CGFloat = 600
    var onConnect: () -> Void
    var onSkip: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background
            Color.black.opacity(0.70)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Bottom sheet
            VStack(spacing: 20) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "3A3A3C"))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                if !showInstructions {
                    // Main content — disconnected state
                    VStack(spacing: 16) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "FF2D55"))

                        Text("Apple Health Disconnected")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("Your steps are no longer synced with Apple Health, because we don't have the permission to.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showInstructions = true
                            }
                        }) {
                            Text("Connect Now")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color(hex: "FF2D55"))
                                .cornerRadius(14)
                        }

                        Button(action: { onSkip?(); dismiss() }) {
                            Text("Continue with Motion Sensor")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "8E8E93"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color(hex: "1C1C1E"))
                                .cornerRadius(14)
                        }
                    }
                } else {
                    // Instructions content
                    VStack(spacing: 16) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "8E8E93"))

                        Text("We need your permission")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("We need your permission to access Apple Health.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .multilineTextAlignment(.center)
                    }

                    // Steps
                    VStack(alignment: .leading, spacing: 14) {
                        instructionRow(number: "1", icon: "gearshape.fill", iconColor: Color(hex: "8E8E93"), text: "Settings")
                        instructionRow(number: "2", icon: "hand.raised.fill", iconColor: Color(hex: "007AFF"), text: "Privacy & Security")
                        instructionRow(number: "3", icon: "heart.fill", iconColor: Color(hex: "FF2D55"), text: "Health")
                        instructionRow(number: "4", icon: "figure.walk", iconColor: Color(hex: "34C759"), text: "StePlease")
                        instructionRow(number: "5", icon: "togglepower", iconColor: Color(hex: "34C759"), text: "Enable all switches")
                    }
                    .padding(16)
                    .background(Color(hex: "1C1C1E"))
                    .cornerRadius(14)

                    Button(action: {
                        onConnect()
                        dismiss()
                    }) {
                        Text("Open Settings")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(hex: "FF2D55"))
                            .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "161618"))
                    .ignoresSafeArea(edges: .bottom)
            )
            .offset(y: sheetOffset)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                sheetOffset = 0
            }
        }
    }

    @ViewBuilder
    private func instructionRow(number: String, icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "8E8E93"))
                .frame(width: 22)

            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white)
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            sheetOffset = 600
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// MARK: - Step Metric Tile (Distance / Time / Calories)
struct StepMetricTile: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(Color(hex: "8E8E93"))
            
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "121212"))
        .cornerRadius(20)
    }
}

// MARK: - Week Summary Card (W tab)
struct WeekSummaryView: View {
    let totalSteps: Int
    let dailySteps: [Int]       // 7 values Mon-Sun
    let dailyGoalMet: [Bool]
    let avgSteps: Int
    let prevAvgSteps: Int
    let startDate: Date
    let endDate: Date
    let dailyGoal: Int
    let weekStartsMonday: Bool

    @State private var barAnimation: CGFloat = 0

    private let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let dayLabelsSun = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    
    private var labels: [String] {
        weekStartsMonday ? dayLabels : dayLabelsSun
    }
    
    private var todayIndex: Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date()) // 1=Sun..7=Sat
        if weekStartsMonday {
            // Mon=0, Tue=1, ... Sun=6
            return (weekday + 5) % 7
        } else {
            return weekday - 1
        }
    }
    
    private var isCurrentWeek: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return today >= start && today <= end
    }
    
    private var avgIsUp: Bool {
        avgSteps >= prevAvgSteps
    }
    
    private var maxDailySteps: Int {
        max(dailySteps.max() ?? 1, dailyGoal, 1)
    }
    
    private func dateRangeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "en_US")
        let start = formatter.string(from: startDate).uppercased()
        let end = formatter.string(from: endDate).uppercased()
        return "\(start) – \(end)"
    }
    
    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            let k = Double(steps) / 1000.0
            if k >= 10 {
                return "\(Int(k))K"
            } else {
                return String(format: "%.0fK", k)
            }
        }
        return "<1K"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: 50px
            HStack(alignment: .top) {
                // Left: title + total
                VStack(alignment: .leading, spacing: 4) {
                    Text("Week summary")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "8E8E93"))

                    Text("\(totalSteps.formatted())")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.5), value: totalSteps)
                }
                
                Spacer()
                
                // Right: date range + avg
                VStack(alignment: .trailing, spacing: 4) {
                    Text(dateRangeString())
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "8E8E93"))
                    
                    // AVG badge
                    HStack(spacing: 6) {
                        Text("AVG \(avgSteps.formatted())")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Image(systemName: avgIsUp ? "arrow.up.forward.circle" : "arrow.down.forward.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(avgIsUp ? Color(hex: "34C759") : Color.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color(hex: "1A1A1A"))
                    .cornerRadius(8)
                }
            }
            .frame(height: 50)
            
            Spacer().frame(height: 10)
            
            // Bar chart
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let barWidth: CGFloat = 25
                let spacing = (totalWidth - barWidth * 7) / 6
                let chartTop: CGFloat = 20  // space for value labels
                let chartBottom: CGFloat = 30 // space for day labels
                let barAreaHeight = geo.size.height - chartTop - chartBottom
                
                // Goal line Y
                let goalRatio = CGFloat(dailyGoal) / CGFloat(maxDailySteps)
                let goalY = chartTop + barAreaHeight * (1 - goalRatio)
                
                ZStack(alignment: .topLeading) {
                    // Goal dashed line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: goalY))
                        path.addLine(to: CGPoint(x: totalWidth, y: goalY))
                    }
                    .stroke(
                        Color(hex: "34C759").opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                    
                    // Bars + labels
                    ForEach(0..<7, id: \.self) { i in
                        let x = CGFloat(i) * (barWidth + spacing)
                        let steps = dailySteps[i]
                        let ratio = steps > 0 ? CGFloat(steps) / CGFloat(maxDailySteps) : 0
                        let fullBarH = max(ratio * barAreaHeight, steps > 0 ? 8 : 4)
                        let barH = fullBarH * barAnimation
                        let barY = chartTop + barAreaHeight - barH
                        let goalMet = dailyGoalMet[i]
                        let isTodayBar = isCurrentWeek && i == todayIndex
                        let isFuture = isCurrentWeek && i > todayIndex

                        // Value label above bar
                        if steps > 0 {
                            Text(formatSteps(steps))
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(Color(hex: "8E8E93"))
                                .position(x: x + barWidth / 2, y: barY - 10)
                                .opacity(Double(barAnimation))
                        }

                        // Bar
                        if steps > 0 || !isFuture {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(goalMet ? Color(hex: "00CA48") : Color(hex: "373737"))
                                    .frame(width: barWidth, height: barH)

                                if goalMet && steps >= dailyGoal * 2 {
                                    Text("2X")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.bottom, 8)
                                        .opacity(Double(barAnimation))
                                } else if goalMet {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.bottom, 8)
                                        .opacity(Double(barAnimation))
                                }
                            }
                            .position(x: x + barWidth / 2, y: barY + barH / 2)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "373737"))
                                .frame(width: barWidth, height: 4)
                                .position(x: x + barWidth / 2, y: chartTop + barAreaHeight - 2)
                        }

                        // Day label
                        Text(labels[i])
                            .font(.system(size: 10, weight: isTodayBar ? .bold : .regular, design: .monospaced))
                            .foregroundColor(isTodayBar ? .white : Color(hex: "8E8E93"))
                            .position(x: x + barWidth / 2, y: chartTop + barAreaHeight + 18)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(height: 292)
        .background(Color(hex: "121212"))
        .cornerRadius(20)
        .onAppear {
            barAnimation = 0
            withAnimation(.easeOut(duration: 0.8)) {
                barAnimation = 1
            }
        }
    }
}

// MARK: - Month Summary Card (M tab)
struct MonthSummaryView: View {
    let totalSteps: Int
    let dailySteps: [Int]
    let dailyGoalMet: [Bool]
    let avgSteps: Int
    let prevAvgSteps: Int
    let monthDate: Date
    let dailyGoal: Int
    let weekStartsMonday: Bool
    let canGoForward: Bool
    let onPrev: () -> Void
    let onNext: () -> Void

    @State private var calendarAnimation: CGFloat = 0

    private let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let dayLabelsSun = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    
    private var labels: [String] {
        weekStartsMonday ? dayLabels : dayLabelsSun
    }
    
    private var avgIsUp: Bool {
        avgSteps >= prevAvgSteps
    }
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: monthDate)
    }
    
    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: monthDate)?.count ?? 30
    }
    
    private var firstDayOffset: Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: monthDate)
        if weekStartsMonday {
            return (weekday + 5) % 7
        } else {
            return weekday - 1
        }
    }
    
    private var todayDay: Int? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let comp = calendar.dateComponents([.year, .month], from: today)
        let comp2 = calendar.dateComponents([.year, .month], from: monthDate)
        if comp.year == comp2.year && comp.month == comp2.month {
            return calendar.component(.day, from: today)
        }
        return nil
    }
    
    private var totalRows: Int { 5 }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Month summary")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "8E8E93"))

                    Text("\(totalSteps.formatted())")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.5), value: totalSteps)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 12) {
                        Button(action: onPrev) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "8E8E93"))
                        }
                        
                        Text(monthName)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(hex: "8E8E93"))
                        
                        Button(action: onNext) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(canGoForward ? Color(hex: "8E8E93") : Color(hex: "3A3A3C"))
                        }
                        .disabled(!canGoForward)
                    }
                    
                    HStack(spacing: 6) {
                        Text("AVG \(avgSteps.formatted())")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Image(systemName: avgIsUp ? "arrow.up.forward.circle" : "arrow.down.forward.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(avgIsUp ? Color(hex: "34C759") : Color.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color(hex: "1A1A1A"))
                    .cornerRadius(8)
                }
            }
            
            Spacer().frame(height: 10)
            
            // Calendar grid — no vertical gaps
            VStack(spacing: 0) {
                ForEach(0..<totalRows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let cellIndex = row * 7 + col
                            let dayNum = cellIndex - firstDayOffset + 1
                            
                            ZStack {
                                if dayNum >= 1 && dayNum <= daysInMonth {
                                    let isToday = dayNum == todayDay
                                    let isPast = isDayPast(dayNum)
                                    let goalMet = dayNum <= dailyGoalMet.count ? dailyGoalMet[dayNum - 1] : false

                                    if isToday {
                                        Circle()
                                            .stroke(Color(hex: "34C759"), lineWidth: 1)
                                            .frame(width: 30, height: 30)

                                        if goalMet {
                                            Circle()
                                                .fill(Color(hex: "00CA48"))
                                                .frame(width: 24 * calendarAnimation, height: 24 * calendarAnimation)
                                        }

                                        Text("\(dayNum)")
                                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                                            .foregroundColor(goalMet ? .black : .white)
                                    } else if isPast && goalMet {
                                        Circle()
                                            .fill(Color(hex: "00CA48"))
                                            .frame(width: 24 * calendarAnimation, height: 24 * calendarAnimation)

                                        Text("\(dayNum)")
                                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                                            .foregroundColor(.black)
                                    } else if isPast {
                                        Text("\(dayNum)")
                                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                                            .foregroundColor(Color(hex: "9B9B9B"))
                                    } else {
                                        Text("\(dayNum)")
                                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                                            .foregroundColor(Color(hex: "3A3A3C"))
                                    }
                                } else {
                                    Circle()
                                        .fill(Color(hex: "373737"))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Day of week labels — at bottom
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(labels[i])
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(height: 292)
        .background(Color(hex: "121212"))
        .cornerRadius(20)
        .onAppear {
            calendarAnimation = 0
            withAnimation(.easeOut(duration: 0.6)) {
                calendarAnimation = 1
            }
        }
    }

    private func isDayPast(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthDate) else { return false }
        return calendar.startOfDay(for: dayDate) <= today
    }
}

// MARK: - Combined Progress Card (Day / Week toggle)
struct ProgressCardView: View {
    let hourlyStepsToday: [Int]
    let hourlyStepsYesterday: [Int]
    let last7DaysProgress: [Double]
    let last7DaysLabels: [String]
    let last7DaysGoalMet: [Bool]
    let selectedDayOffset: Int
    var monthlyProgress: [Double] = []
    var monthlyGoalMet: [Bool] = []
    var quarterProgress: [Double] = []
    var quarterGoalMet: [Bool] = []
    
    @State private var selectedPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var animationProgress: CGFloat = 0

    private let chartHeight: CGFloat = 72
    private let totalContentHeight: CGFloat = 92
    private let pageCount = 4
    
    private var pageTitle: String {
        switch selectedPage {
        case 0: return "Day Progress"
        case 1: return "Week Progress"
        case 2: return "Quarter Progress"
        case 3: return "Year Progress"
        default: return "Progress"
        }
    }
    
    private var selectedChartIndex: Int {
        return max(0, min(6, 6 - selectedDayOffset))
    }
    
    private let monthLabels = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title area
            HStack(spacing: 10) {
                Text(pageTitle)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .animation(.none, value: selectedPage)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
                
                Spacer()
                
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Circle()
                            .fill(index == selectedPage ? Color(hex: "BFBFBF") : Color(hex: "3A3A3C"))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.vertical, 4)
            }
            
            ZStack {
                if selectedPage == 0 {
                    dayProgressContent.transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else if selectedPage == 1 {
                    weekProgressContent.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                } else if selectedPage == 2 {
                    quarterProgressContent.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                } else {
                    yearProgressContent.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                }
            }
            .frame(height: totalContentHeight)
            .offset(x: dragOffset)
        }
        .padding(16)
        .background(Color(hex: "121212"))
        .cornerRadius(20)
        .contentShape(Rectangle())
        .onAppear {
            animationProgress = 0
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1
            }
        }
        .onChange(of: selectedPage) { _, _ in
            animationProgress = 0
            withAnimation(.easeOut(duration: 0.7)) {
                animationProgress = 1
            }
        }
        .onTapGesture {
            // Tap anywhere on card to go to next page
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedPage = (selectedPage + 1) % pageCount
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in dragOffset = value.translation.width * 0.3 }
                .onEnded { value in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { dragOffset = 0 }
                    let threshold: CGFloat = 40
                    if value.translation.width < -threshold {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selectedPage = (selectedPage + 1) % pageCount }
                    } else if value.translation.width > threshold {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selectedPage = (selectedPage - 1 + pageCount) % pageCount }
                    }
                }
        )
    }
    
    /// Filter out noise from hourly step data.
    /// HealthKit distributes samples across hour boundaries, producing small step counts
    /// during hours when no real walking occurred (e.g. 50-200 steps at 3 AM).
    /// Uses a dynamic threshold: any hour with less than 2% of the peak hour is treated as noise.
    /// Also applies an absolute minimum of 50 steps.
    private func cleanedHourlySteps(_ raw: [Int]) -> [Int] {
        let peak = raw.max() ?? 0
        let dynamicThreshold = max(50, Int(Double(peak) * 0.02))
        return raw.map { $0 >= dynamicThreshold ? $0 : 0 }
    }

    private var dayProgressContent: some View {
        let cleanToday = cleanedHourlySteps(hourlyStepsToday)
        let cleanYesterday = cleanedHourlySteps(hourlyStepsYesterday)
        let maxSteps = max(cleanToday.max() ?? 1, cleanYesterday.max() ?? 1, 1)
        return VStack(spacing: 4) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<24, id: \.self) { hour in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            ZStack(alignment: .bottom) {
                                // Yesterday (gray) bar — only show if there were actual steps
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "373737"))
                                    .frame(height: barHeight(steps: cleanYesterday[hour], max: maxSteps, placeholder: true) * animationProgress)
                                // Today (green) bar — only show for meaningful step counts
                                if cleanToday[hour] > 0 {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: "00CA48"))
                                        .frame(height: barHeight(steps: cleanToday[hour], max: maxSteps) * animationProgress)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: chartHeight)
            .animation(.easeInOut(duration: 0.4), value: hourlyStepsToday)
            .animation(.easeInOut(duration: 0.4), value: hourlyStepsYesterday)
            HStack {
                ForEach(["0", "6", "12", "18", "24"], id: \.self) { label in
                    if label != "0" { Spacer() }
                    Text(label).font(.system(size: 10, weight: .regular, design: .monospaced)).foregroundColor(Color(hex: "8E8E93"))
                }
            }
            .frame(height: 16)
        }
    }
    
    private var weekProgressContent: some View {
        let rawMax = last7DaysProgress.max() ?? 1.0
        let chartMax = max(rawMax, 1.0) * 1.3
        return VStack(spacing: 4) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let inset: CGFloat = 12
                let usable = width - inset * 2
                let stepX = usable / 6
                let goalY = height - (height * (1.0 / chartMax))

                ZStack(alignment: .topLeading) {
                    ForEach(0..<7, id: \.self) { i in
                        Path { path in let x = inset + CGFloat(i) * stepX; path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: height)) }.stroke(Color(hex: "1A1A1A"), lineWidth: 1)
                    }
                    Path { path in path.move(to: CGPoint(x: 0, y: goalY)); path.addLine(to: CGPoint(x: width, y: goalY)) }.stroke(Color(hex: "34C759").opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    let points: [CGPoint] = (0..<7).map { i in CGPoint(x: inset + CGFloat(i) * stepX, y: height - (height * (min(last7DaysProgress[i], chartMax) / chartMax))) }
                    // Fill area
                    Path { path in guard !points.isEmpty else { return }; path.move(to: CGPoint(x: points[0].x, y: height)); path.addLine(to: points[0]); for i in 1..<points.count { path.addLine(to: points[i]) }; path.addLine(to: CGPoint(x: points.last!.x, y: height)); path.closeSubpath() }.fill(LinearGradient(colors: [Color(hex: "34C759").opacity(0.25), Color(hex: "34C759").opacity(0)], startPoint: .top, endPoint: .bottom)).opacity(Double(animationProgress))
                    // Line with trim animation
                    Path { path in guard !points.isEmpty else { return }; path.move(to: points[0]); for i in 1..<points.count { path.addLine(to: points[i]) } }.trim(from: 0, to: animationProgress).stroke(Color(hex: "34C759"), lineWidth: 2)

                    ForEach(0..<7, id: \.self) { i in
                        let x = inset + CGFloat(i) * stepX
                        let y = height - (height * (min(last7DaysProgress[i], chartMax) / chartMax))
                        ZStack {
                            if i == selectedChartIndex { Circle().stroke(Color.white.opacity(0.4), lineWidth: 2).frame(width: 10, height: 10) }
                            Circle().fill(last7DaysGoalMet[i] ? Color(hex: "34C759") : Color(hex: "B8B8B8")).frame(width: 6, height: 6)
                        }.position(x: x, y: y).opacity(Double(animationProgress))
                    }
                }
            }
            .frame(height: chartHeight)
            GeometryReader { geo in
                let width = geo.size.width; let inset: CGFloat = 12; let usable = width - inset * 2; let stepX = usable / 6
                ForEach(0..<7, id: \.self) { i in
                    Text(last7DaysLabels.count > i ? last7DaysLabels[i] : "").font(.system(size: 10, weight: i == selectedChartIndex ? .semibold : .regular, design: .monospaced)).foregroundColor(i == selectedChartIndex ? .white : Color(hex: "8E8E93")).position(x: inset + CGFloat(i) * stepX, y: 8)
                }
            }.frame(height: 16)
        }
    }
    
    private var quarterProgressContent: some View {
        let quarterData: [Double] = quarterProgress.count == 12 ? quarterProgress : Array(repeating: 0.7, count: 12)
        let quarterGoalMetData: [Bool] = quarterGoalMet.count == 12 ? quarterGoalMet : Array(repeating: true, count: 12)
        let rawMax = quarterData.max() ?? 1.0
        let chartMax = max(rawMax, 1.0) * 1.3
        let calendar = Calendar.current
        let today = Date()

        return VStack(spacing: 4) {
            GeometryReader { geo in
                let width = geo.size.width; let height = geo.size.height; let inset: CGFloat = 8; let usable = width - inset * 2; let stepX = usable / 11
                ZStack(alignment: .topLeading) {
                    ForEach(0..<12, id: \.self) { i in
                        Path { path in let x = inset + CGFloat(i) * stepX; path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: height)) }.stroke(Color(hex: "1A1A1A"), lineWidth: 1)
                    }
                    let points: [CGPoint] = (0..<12).map { i in CGPoint(x: inset + CGFloat(i) * stepX, y: height - (height * (min(quarterData[i], chartMax) / chartMax))) }
                    Path { path in guard !points.isEmpty else { return }; path.move(to: CGPoint(x: points[0].x, y: height)); path.addLine(to: points[0]); for i in 1..<points.count { path.addLine(to: points[i]) }; path.addLine(to: CGPoint(x: points.last!.x, y: height)); path.closeSubpath() }.fill(LinearGradient(colors: [Color(hex: "34C759").opacity(0.25), Color(hex: "34C759").opacity(0)], startPoint: .top, endPoint: .bottom)).opacity(Double(animationProgress))
                    Path { path in guard !points.isEmpty else { return }; path.move(to: points[0]); for i in 1..<points.count { path.addLine(to: points[i]) } }.trim(from: 0, to: animationProgress).stroke(Color(hex: "34C759"), lineWidth: 2)
                    ForEach(0..<12, id: \.self) { i in
                        let x = inset + CGFloat(i) * stepX
                        let y = height - (height * (min(quarterData[i], chartMax) / chartMax))
                        ZStack {
                            if i == 11 { Circle().stroke(Color.white.opacity(0.4), lineWidth: 2).frame(width: 10, height: 10) }
                            Circle().fill(quarterGoalMetData[i] ? Color(hex: "34C759") : Color(hex: "B8B8B8")).frame(width: 6, height: 6)
                        }.position(x: x, y: y).opacity(Double(animationProgress))
                    }
                }
            }.frame(height: chartHeight)
            GeometryReader { geo in
                let width = geo.size.width; let inset: CGFloat = 8; let usable = width - inset * 2; let stepX = usable / 11
                let weekDates: [Date] = (0..<12).map { i in calendar.date(byAdding: .weekOfYear, value: -(11 - i), to: today) ?? today }
                ForEach([0, 4, 8, 11], id: \.self) { i in
                    let monthIndex = calendar.component(.month, from: weekDates[i]) - 1
                    Text(monthLabels[monthIndex]).font(.system(size: 9, weight: i == 11 ? .semibold : .regular, design: .monospaced)).foregroundColor(i == 11 ? .white : Color(hex: "8E8E93")).position(x: inset + CGFloat(i) * stepX, y: 8)
                }
            }.frame(height: 16)
        }
    }
    
    private var yearProgressContent: some View {
        let yearData: [Double] = monthlyProgress.count == 12 ? monthlyProgress : Array(repeating: 0.8, count: 12)
        let yearGoalMetData: [Bool] = monthlyGoalMet.count == 12 ? monthlyGoalMet : Array(repeating: true, count: 12)
        let rawMax = yearData.max() ?? 1.0
        let chartMax = max(rawMax, 1.0) * 1.3
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date()) - 1
        let reorderedData: [Double] = (0..<12).map { i in let idx = (currentMonth - 11 + i + 12) % 12; return yearData.count > idx ? yearData[idx] : 0.0 }
        let reorderedGoalMet: [Bool] = (0..<12).map { i in let idx = (currentMonth - 11 + i + 12) % 12; return yearGoalMetData.count > idx ? yearGoalMetData[idx] : false }
        let reorderedLabels: [String] = (0..<12).map { i in let idx = (currentMonth - 11 + i + 12) % 12; return monthLabels[idx] }

        return VStack(spacing: 4) {
            GeometryReader { geo in
                let width = geo.size.width; let height = geo.size.height; let inset: CGFloat = 8; let usable = width - inset * 2; let stepX = usable / 11
                ZStack(alignment: .topLeading) {
                    ForEach(0..<12, id: \.self) { i in
                        Path { path in let x = inset + CGFloat(i) * stepX; path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: height)) }.stroke(Color(hex: "1A1A1A"), lineWidth: 1)
                    }
                    let points: [CGPoint] = (0..<12).map { i in CGPoint(x: inset + CGFloat(i) * stepX, y: height - (height * (min(reorderedData[i], chartMax) / chartMax))) }
                    Path { path in guard !points.isEmpty else { return }; path.move(to: CGPoint(x: points[0].x, y: height)); path.addLine(to: points[0]); for i in 1..<points.count { path.addLine(to: points[i]) }; path.addLine(to: CGPoint(x: points.last!.x, y: height)); path.closeSubpath() }.fill(LinearGradient(colors: [Color(hex: "34C759").opacity(0.25), Color(hex: "34C759").opacity(0)], startPoint: .top, endPoint: .bottom)).opacity(Double(animationProgress))
                    Path { path in guard !points.isEmpty else { return }; path.move(to: points[0]); for i in 1..<points.count { path.addLine(to: points[i]) } }.trim(from: 0, to: animationProgress).stroke(Color(hex: "34C759"), lineWidth: 2)
                    ForEach(0..<12, id: \.self) { i in
                        let x = inset + CGFloat(i) * stepX
                        let y = height - (height * (min(reorderedData[i], chartMax) / chartMax))
                        ZStack {
                            if i == 11 { Circle().stroke(Color.white.opacity(0.4), lineWidth: 2).frame(width: 10, height: 10) }
                            Circle().fill(reorderedGoalMet[i] ? Color(hex: "34C759") : Color(hex: "B8B8B8")).frame(width: 6, height: 6)
                        }.position(x: x, y: y).opacity(Double(animationProgress))
                    }
                }
            }.frame(height: chartHeight)
            GeometryReader { geo in
                let width = geo.size.width; let inset: CGFloat = 8; let usable = width - inset * 2; let stepX = usable / 11
                ForEach([0, 3, 6, 9, 11], id: \.self) { i in
                    Text(reorderedLabels[i]).font(.system(size: 9, weight: i == 11 ? .semibold : .regular, design: .monospaced)).foregroundColor(i == 11 ? .white : Color(hex: "8E8E93")).position(x: inset + CGFloat(i) * stepX, y: 8)
                }
            }.frame(height: 16)
        }
    }
    
    private func barHeight(steps: Int, max: Int, placeholder: Bool = false) -> CGFloat {
        if steps == 0 { return placeholder ? 1 : 0 }
        let proportional = CGFloat(steps) / CGFloat(max) * chartHeight
        // Placeholder (yesterday) bars: min 2px so they're subtly visible
        // Today bars: min 3px so real activity is always visible
        return Swift.max(placeholder ? 2 : 3, proportional)
    }
}


// MARK: - Streak View (legacy, kept for reference)
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
        EmptyView()
    }
}

// MARK: - Bottom Navigation
// MARK: - Bottom Navigation View (iOS 26 Liquid Glass Style)
struct BottomNavigationView: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    
    private let tabs: [(icon: String, title: String)] = [
        ("figure.walk", "Steps"),
        ("star", "Leaderbord"),
        ("crown", "Awards"),
        ("gearshape", "Settings")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    TabBarButton(
                        icon: tab.icon,
                        title: tab.title,
                        isSelected: selectedTab == index,
                        namespace: animation
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedTab = index
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    Capsule()
                        .fill(Color(hex: "0A0A0A").opacity(0.95))
                    
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(0.1)
                    
                    Capsule()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.25), location: 0),
                                    .init(color: Color.white.opacity(0.15), location: 0.3),
                                    .init(color: Color.white.opacity(0.05), location: 0.7),
                                    .init(color: Color.white.opacity(0.02), location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(Capsule())
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, -9)
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "34C759") : Color.white.opacity(0.5))
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "34C759") : Color.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if isSelected {
                        ZStack {
                            Capsule()
                                .fill(Color(hex: "1A1A1A"))
                            
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(0.3), location: 0),
                                            .init(color: Color.white.opacity(0.15), location: 0.3),
                                            .init(color: Color.white.opacity(0.05), location: 0.7),
                                            .init(color: Color.white.opacity(0.0), location: 1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .matchedGeometryEffect(id: "TAB_BG", in: namespace)
                    }
                }
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
                            VStack(spacing: 16) {
                                Text("🎯")
                                    .font(.system(size: 60))
                                
                                Text("Set your daily step goal")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
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
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            if selectedGoal == goalValue && !showCustomInput {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(Color(hex: "34C759"))
                                                    .font(.system(size: 14, weight: .bold))
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .frame(height: 56)
                                        .background(Color(hex: "1A1A1C"))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedGoal == goalValue && !showCustomInput ? Color(hex: "34C759") : Color.clear, lineWidth: 1.5)
                                        )
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

// MARK: - Leaderboard Locked View (for anonymous users)
struct LeaderboardLockedView: View {
    @ObservedObject var authManager: AuthManager
    @State private var showEmailLogin = false
    @State private var showEmailRegister = false
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "8E8E93"))
                    
                    Text("Sign in to compete")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Create an account or sign in to join the leaderboard and compete with friends")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    // Sign in with Apple (custom button for consistent font)
                    Button(action: {
                        authManager.signInWithApple()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 17, weight: .medium))
                            Text("Sign up with Apple")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading)
                    .opacity(authManager.isLoading ? 0.6 : 1)
                    
                    // Sign in with Google
                    Button(action: {
                        authManager.signInWithGoogle()
                    }) {
                        HStack(spacing: 8) {
                            GoogleLogo()
                                .frame(width: 17, height: 17)
                            Text("Sign up with Google")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    
                    // Sign up with Email
                    Button(action: {
                        showEmailRegister = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 15))
                            Text("Sign up with Email")
                                .font(.system(size: 16, weight: .medium))
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
                    
                    Button(action: {
                        showEmailLogin = true
                    }) {
                        Text("Already have an account? ")
                            .foregroundColor(Color(hex: "8E8E93"))
                        + Text("Sign In")
                            .foregroundColor(Color(hex: "34C759"))
                    }
                    .font(.system(size: 15))
                    .padding(.top, 8)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 120)
            }
        }
        .sheet(isPresented: $showEmailLogin) {
            EmailLoginView(authManager: authManager, isRegistering: false)
        }
        .sheet(isPresented: $showEmailRegister) {
            EmailLoginView(authManager: authManager, isRegistering: true)
        }
    }
}

// MARK: - Leaderboard Hidden View
struct LeaderboardHiddenView: View {
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A").ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "8E8E93"))
                Text("Leaderboard is Hidden")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("You can enable it in Settings")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8E8E93"))
                Spacer()
            }
        }
    }
}

// MARK: - Friends Empty State View
struct FriendsEmptyStateView: View {
    @ObservedObject var leaderboardManager: LeaderboardManager
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "8E8E93"))
            Text("No friends yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            Text("Invite friends to compete together")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "8E8E93"))
            Button(action: {
                guard !isLoading else { return }
                isLoading = true
                leaderboardManager.getFriendInviteShareItems { items in
                    shareItems = items
                    isLoading = false
                    if !items.isEmpty {
                        showShareSheet = true
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text("Invite Friend")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(hex: "34C759"))
                .cornerRadius(12)
            }
            .padding(.top, 8)
            Spacer()
            Spacer()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .onAppear {
            // Pre-generate invite code so it's cached when button is tapped
            leaderboardManager.generateFriendInviteCode { _ in }
        }
    }
}

// MARK: - Top Leaderboard View
struct TopLeaderboardView: View {
    @ObservedObject var leaderboardManager: LeaderboardManager
    @ObservedObject var authManager: AuthManager
    @ObservedObject var groupManager: GroupManager
    @State private var selectedUser: LeaderboardUser?
    @State private var showMyProfile = false
    @State private var showProfile = false
    @State private var selectedTab: GroupTab = .friends
    @State private var showGroupDetail: CustomGroup? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var showMenu = false
    @State private var showShareSheet = false
    @State private var showStepsShareSheet = false
    
    let appStoreLink = "https://apps.apple.com/rs/app/steplease-step-tracker/id6758054873"
    
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
    
    var isToday: Bool {
        let calendar = Calendar.current
        if leaderboardManager.selectedPeriod == 0 {
            return calendar.isDateInToday(leaderboardManager.selectedDate)
        } else if leaderboardManager.selectedPeriod == 1 {
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: leaderboardManager.selectedDate))!
            let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
            return weekStart == currentWeekStart
        } else {
            return calendar.component(.month, from: leaderboardManager.selectedDate) == calendar.component(.month, from: Date()) &&
                   calendar.component(.year, from: leaderboardManager.selectedDate) == calendar.component(.year, from: Date())
        }
    }
    
    var dateString: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        
        if leaderboardManager.selectedPeriod == 0 {
            if calendar.isDateInToday(leaderboardManager.selectedDate) {
                return "Today"
            } else if calendar.isDateInYesterday(leaderboardManager.selectedDate) {
                return "Yesterday"
            } else {
                formatter.dateFormat = "MMM d"
                return formatter.string(from: leaderboardManager.selectedDate)
            }
        } else if leaderboardManager.selectedPeriod == 1 {
            formatter.dateFormat = "MMM d"
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: leaderboardManager.selectedDate))!
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
        } else {
            formatter.dateFormat = "MMMM"
            return formatter.string(from: leaderboardManager.selectedDate)
        }
    }
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation (exactly like main screen)
                HStack(spacing: 0) {
                    // Profile button (left) - same style as TopNavigationView
                    Button(action: { showProfile = true }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "0A0A0A").opacity(0.95))
                            
                            if !authManager.isAnonymous && !authManager.userName.isEmpty {
                                Circle()
                                    .fill(Color(hex: "34C759"))
                                
                                Text(String(authManager.userName.prefix(1)).uppercased())
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.black)
                            } else {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            stops: [
                                                .init(color: Color.white.opacity(0.25), location: 0),
                                                .init(color: Color.white.opacity(0.1), location: 0.5),
                                                .init(color: Color.white.opacity(0.02), location: 1)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                                
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    // Period selector (D W M) - exactly like TopNavigationView
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { index in
                            let labels = ["D", "W", "M"]
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    leaderboardManager.selectedPeriod = index
                                    leaderboardManager.refresh()
                                }
                            }) {
                                ZStack {
                                    if leaderboardManager.selectedPeriod == index {
                                        Circle()
                                            .fill(Color(hex: "1A1A1A"))
                                            .frame(width: 36, height: 36)
                                    }
                                    
                                    Text(labels[index])
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(leaderboardManager.selectedPeriod == index ? .white : Color(hex: "8E8E93"))
                                }
                                .frame(width: 36, height: 36)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(Color(hex: "0A0A0A").opacity(0.95))
                            
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(0.25), location: 0),
                                            .init(color: Color.white.opacity(0.1), location: 0.5),
                                            .init(color: Color.white.opacity(0.02), location: 1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        }
                    )
                    .frame(height: 44)
                    
                    Spacer()
                    
                    // Menu button (right) - same style
                    Button(action: { withAnimation(.easeOut(duration: 0.2)) { showMenu = true } }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "0A0A0A").opacity(0.95))
                            
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(0.25), location: 0),
                                            .init(color: Color.white.opacity(0.1), location: 0.5),
                                            .init(color: Color.white.opacity(0.02), location: 1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                            
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(width: 44, height: 44)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Date Header (72px height, chevrons centered around date)
                HStack(spacing: 0) {
                    Spacer()

                    HStack(spacing: 16) {
                        // Left chevron
                        Button(action: { changeDate(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())

                        // Date text + optional Today button
                        HStack(spacing: 8) {
                            Text(dateString)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(isToday ? .white : Color(hex: "8E8E93"))

                            if leaderboardManager.selectedPeriod == 0 && !isToday {
                                Button(action: {
                                    withAnimation {
                                        leaderboardManager.selectedDate = Date()
                                        leaderboardManager.refresh()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 10, weight: .medium))
                                        Text("Today")
                                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    }
                                    .foregroundColor(.white)
                                }
                            }
                        }

                        // Right chevron
                        Button(action: { if canGoForward { changeDate(by: 1) } }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(canGoForward ? .white : Color(hex: "3A3A3C"))
                        }
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                        .disabled(!canGoForward)
                    }

                    Spacer()
                }
                .frame(height: 72)
                .padding(.horizontal, 0)
                .background(Color(hex: "0A0A0A"))
                .zIndex(1)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            dragOffset = value.translation.width * 0.3
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                            if value.translation.width > 50 {
                                changeDate(by: -1)
                            } else if value.translation.width < -50 && canGoForward {
                                changeDate(by: 1)
                            }
                        }
                )
                
                // Group Tab Selector
                GroupTabSelector(
                    leaderboardManager: leaderboardManager,
                    groupManager: groupManager,
                    selectedTab: $selectedTab
                )

                // Leaderboard Content (based on selected tab)
                if leaderboardManager.isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else {
                    switch selectedTab {
                    case .friends:
                        // Show empty state if no friends (exclude self)
                        let realFriends = leaderboardManager.friends.filter { $0 != leaderboardManager.currentUserID }
                        if realFriends.isEmpty {
                            FriendsEmptyStateView(leaderboardManager: leaderboardManager)
                        } else {
                            leaderboardTableHeader
                            NewLeaderboardList(
                                leaderboardManager: leaderboardManager,
                                onUserTap: { user in selectedUser = user },
                                onSwipeDate: { value in changeDate(by: value) }
                            )
                        }
                    case .all:
                        if leaderboardManager.filteredUsers.isEmpty {
                            Spacer()
                            Text("No users yet")
                                .font(.system(size: 17))
                                .foregroundColor(Color(hex: "8E8E93"))
                            Spacer()
                        } else {
                            leaderboardTableHeader
                            NewLeaderboardList(
                                leaderboardManager: leaderboardManager,
                                onUserTap: { user in selectedUser = user },
                                onSwipeDate: { value in changeDate(by: value) }
                            )
                        }
                    case .group(let groupId):
                        if groupManager.userGroups.contains(where: { $0.id == groupId }) {
                            GroupLeaderboardView(
                                groupId: groupId,
                                groupManager: groupManager,
                                leaderboardManager: leaderboardManager
                            )
                        } else {
                            Spacer()
                            Text("Group not found")
                                .font(.system(size: 17))
                                .foregroundColor(Color(hex: "8E8E93"))
                            Spacer()
                        }
                    }
                }
            }
            
            // Bottom gradient overlay
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color(hex: "0A0A0A").opacity(0), Color(hex: "0A0A0A")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            // Menu Overlay
            if showMenu {
                Color.black.opacity(0.80)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) { showMenu = false }
                    }
                
                VStack {
                    HStack {
                        Spacer()
                        
                        // Menu positioned at top right with border
                        VStack(spacing: 0) {
                            // Invite Friends
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) { showMenu = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showShareSheet = true
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16))
                                        .frame(width: 20, height: 20)
                                    Text("Invite Friends")
                                        .font(.system(size: 15, weight: .regular))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .contentShape(Rectangle())
                            
                            // Share Steps
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) { showMenu = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showStepsShareSheet = true
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 16))
                                        .frame(width: 20, height: 20)
                                    Text("Share Steps")
                                        .font(.system(size: 15, weight: .regular))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .contentShape(Rectangle())
                        }
                        .background(Color(hex: "1C1C1E"))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "3A3A3C"), lineWidth: 0.5)
                        )
                        .fixedSize(horizontal: true, vertical: true)
                        .padding(.trailing, 16)
                        .padding(.top, 60)
                    }
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }
        }
        .sheet(item: $selectedUser) { user in
            UserProfileView(user: user, leaderboardManager: leaderboardManager, authManager: authManager)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(authManager: authManager, healthManager: HealthManager())
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Join me on StePlease! Track your steps and compete with friends! \(appStoreLink)"])
        }
        .sheet(isPresented: $showStepsShareSheet) {
            // Steps banner share - TODO: implement proper banner generation
            ShareSheet(items: ["I walked \(leaderboardManager.users.first(where: { $0.id == leaderboardManager.currentUserID })?.steps.formatted() ?? "0") steps today! 🚶‍♂️ Track your steps with StePlease! \(appStoreLink)"])
        }
        .onAppear {
            // Sync showFriendsOnly with default tab (.friends)
            if selectedTab == .friends {
                leaderboardManager.showFriendsOnly = true
            }
        }
    }

    var leaderboardTableHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("#")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "636366"))
                    .frame(width: 40, alignment: .center)

                Text("User")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "636366"))

                Spacer()

                Text("Steps")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "636366"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            Rectangle()
                .fill(Color(hex: "1A1A1A"))
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
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

// MARK: - New Leaderboard List
struct NewLeaderboardList: View {
    @ObservedObject var leaderboardManager: LeaderboardManager
    var onUserTap: ((LeaderboardUser) -> Void)?
    var onSwipeDate: ((Int) -> Void)? // Callback for date change
    @State private var currentUserRowPosition: CGFloat? = nil
    @State private var scrollViewHeight: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    
    var currentUserRank: Int? {
        leaderboardManager.filteredUsers.firstIndex(where: { $0.id == leaderboardManager.currentUserID }).map { $0 + 1 }
    }
    
    var isCurrentUserVisible: Bool {
        guard let position = currentUserRowPosition else { return false }
        let bottomThreshold = scrollViewHeight - 140
        return position >= 0 && position < bottomThreshold
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(leaderboardManager.filteredUsers.enumerated()), id: \.element.id) { index, user in
                            NewLeaderboardRow(
                                rank: index + 1,
                                user: user,
                                isCurrentUser: user.id == leaderboardManager.currentUserID
                            )
                            .onTapGesture { onUserTap?(user) }
                            .opacity(shouldHideInList(user: user) ? 0 : 1)
                            .background(
                                Group {
                                    if user.id == leaderboardManager.currentUserID {
                                        GeometryReader { rowGeometry in
                                            Color.clear.preference(
                                                key: CurrentUserPositionKey.self,
                                                value: rowGeometry.frame(in: .named("leaderboardScroll")).minY
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 160)
                }
                .coordinateSpace(name: "leaderboardScroll")
                .onPreferenceChange(CurrentUserPositionKey.self) { position in
                    currentUserRowPosition = position
                }
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onChanged { value in
                            dragOffset = value.translation.width * 0.3
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                            if value.translation.width > 50 {
                                onSwipeDate?(-1) // Go back
                            } else if value.translation.width < -50 {
                                onSwipeDate?(1) // Go forward
                            }
                        }
                )
                
                // Sticky current user row when not visible (no top line, moved down 8px)
                if !isCurrentUserVisible, let rank = currentUserRank {
                    if let currentUser = leaderboardManager.filteredUsers.first(where: { $0.id == leaderboardManager.currentUserID }) {
                        NewLeaderboardRow(
                            rank: rank,
                            user: currentUser,
                            isCurrentUser: true,
                            showDivider: false
                        )
                        .onTapGesture { onUserTap?(currentUser) }
                        .background(Color(hex: "101010"))
                        .padding(.bottom, 80) // Moved down 8px more (was 88, now 80 = closer to tab bar)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.2), value: isCurrentUserVisible)
                    }
                }
            }
            .onAppear { scrollViewHeight = geometry.size.height }
            .onChange(of: geometry.size.height) { _, newHeight in scrollViewHeight = newHeight }
        }
    }
    
    private func shouldHideInList(user: LeaderboardUser) -> Bool {
        return user.id == leaderboardManager.currentUserID && !isCurrentUserVisible
    }
}

// MARK: - New Leaderboard Row
struct NewLeaderboardRow: View {
    let rank: Int
    let user: LeaderboardUser
    let isCurrentUser: Bool
    var showDivider: Bool = true
    
    var rankDisplay: AnyView {
        switch rank {
        case 1:
            return AnyView(Text("🥇").font(.system(size: 28)))
        case 2:
            return AnyView(Text("🥈").font(.system(size: 28)))
        case 3:
            return AnyView(Text("🥉").font(.system(size: 28)))
        default:
            return AnyView(
                Text("\(rank)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Rank (40px width)
                rankDisplay
                    .frame(width: 40, alignment: .center)
                
                // Avatar (36x36)
                ZStack {
                    Circle()
                        .fill(isCurrentUser ? Color(hex: "34C759") : Color(hex: "3A3A3C"))
                        .frame(width: 36, height: 36)
                    
                    if isCurrentUser {
                        Circle()
                            .stroke(Color(hex: "34C759"), lineWidth: 2)
                            .frame(width: 42, height: 42)
                    }
                    
                    Text(user.avatarLetter)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isCurrentUser ? .black : .white)
                }
                
                // Name
                Text(user.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isCurrentUser ? .white : Color(hex: "8E8E93"))
                
                Spacer()
                
                // Steps
                Text(user.steps.formatted())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            // Bottom divider - full width with 16px padding on both sides
            if showDivider {
                Rectangle()
                    .fill(Color(hex: "1A1A1A"))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }
        }
        .contentShape(Rectangle())
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

// MARK: - Awards View (Placeholder)
struct AwardsView: View {
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "34C759"))
                
                Text("Awards")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Coming soon...")
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
        }
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

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func scheduleDailyReminder(at time: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "Time to walk! 🚶"
        content.body = "Don't forget to reach your step goal today."
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        center.add(request)
    }
    
    func scheduleGoalAchievedCheck(goal: Int) {
        // Motivational notifications at different times
        let center = UNUserNotificationCenter.current()
        
        let messages = [
            ("morning_motivation", 8, 0, "Good morning! ☀️", "Start your day with a walk — your step goal is waiting!"),
            ("midday_check", 13, 0, "Halfway there? 🏃", "Check your progress — you might be closer to your goal than you think!"),
            ("evening_push", 19, 0, "Final stretch! 💪", "Still have steps to go? A short evening walk can make all the difference.")
        ]
        
        for (id, hour, minute, title, body) in messages {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
    }
    
    func removeAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }
}
