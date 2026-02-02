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
    @State private var useMetric = true       // true = km/kg, false = mi/lbs
    @State private var weekStartsMonday = true // true = Monday, false = Sunday
    
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
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
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
                    
                    // Invite Friend Card
                    InviteFriendCard()
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "NEWS & SUPPORT")
                        
                        VStack(spacing: 0) {
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
                // Default 9 PM
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = 21
                components.minute = 0
                dailyReminderTime = Calendar.current.date(from: components) ?? Date()
            }
            // Load unit preferences (default: metric, Monday)
            if UserDefaults.standard.object(forKey: "use_metric") != nil {
                useMetric = UserDefaults.standard.bool(forKey: "use_metric")
            }
            if UserDefaults.standard.object(forKey: "week_starts_monday") != nil {
                weekStartsMonday = UserDefaults.standard.bool(forKey: "week_starts_monday")
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(authManager: authManager, healthManager: healthManager)
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorView(goal: $healthManager.dailyGoal)
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
    var authManager: AuthManager? = nil
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
                // Profile action - placeholder
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
            
            // Right - Options button
            Button(action: {
                showCalendar = true
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
    let dateLabel: String  // "Today", "Yesterday", "16 Jan 26"
    let isToday: Bool
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    let canGoRight: Bool
    
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
    
    // Circle specs
    private let containerSize: CGFloat = 280
    private let circleSize: CGFloat = 270
    private let strokeWidth: CGFloat = 10
    private let innerCircleSize: CGFloat = 250
    private let innerStrokeWidth: CGFloat = 2
    
    var body: some View {
        HStack(spacing: 24) {
            // Left dot — always visible, tap to go back
            Circle()
                .fill(Color(hex: "B8B8B8"))
                .frame(width: 8, height: 8)
                .onTapGesture { onSwipeLeft() }
            
            // Main circle container
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
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .frame(width: 34, height: 34)
                    
                    // Date label — "Today", "Yesterday", or date
                    Text(goalReached ? "Goal Achieved" : dateLabel)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(goalReached ? Color(hex: "00CA48") : Color(hex: "8E8E93"))
                    
                    Text("\(steps.formatted())")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    
                    Text("Goal \(goal.formatted())")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "8E8E93"))
                    
                    ZStack {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    .frame(width: 34, height: 34)
                }
            }
            .frame(width: containerSize, height: containerSize)
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.width < -30 {
                            onSwipeLeft()
                        } else if value.translation.width > 30 {
                            onSwipeRight()
                        }
                    }
            )
            
            // Right dot — dim if today (can't go forward)
            Circle()
                .fill(Color(hex: canGoRight ? "B8B8B8" : "1F1F1F"))
                .frame(width: 8, height: 8)
                .onTapGesture {
                    if canGoRight { onSwipeRight() }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
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

// MARK: - Streak Tile
struct StreakTile: View {
    let currentStreak: Int
    let maxStreak: Int
    
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
    }
}

// MARK: - Best Day Tile
struct BestDayTile: View {
    let bestSteps: Int
    let bestDate: Date?
    
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

// MARK: - Combined Progress Card (Day / Week toggle)
struct ProgressCardView: View {
    let hourlyStepsToday: [Int]
    let hourlyStepsYesterday: [Int]
    let weekProgress: [Double]  // 0.0-1.0+ for each day of week
    let weekStartsMonday: Bool
    let currentDayIndex: Int    // 0-6, which day of week is today
    
    @State private var selectedPage = 0  // 0 = Day, 1 = Week
    
    private let chartHeight: CGFloat = 72
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with dots
            HStack(spacing: 10) {
                Text(selectedPage == 0 ? "Day progress" : "Week Progress")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(hex: "8E8E93"))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
                
                Spacer()
                
                // Page indicator dots
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index == selectedPage ? Color(hex: "BFBFBF") : Color(hex: "3A3A3C"))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.vertical, 4)
            }
            
            if selectedPage == 0 {
                dayProgressContent
            } else {
                weekProgressContent
            }
        }
        .padding(16)
        .background(Color(hex: "121212"))
        .cornerRadius(20)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedPage = selectedPage == 0 ? 1 : 0
            }
        }
    }
    
    // MARK: - Day Progress (hourly bars)
    private var dayProgressContent: some View {
        let maxSteps = max(hourlyStepsToday.max() ?? 1, hourlyStepsYesterday.max() ?? 1, 1)
        
        return VStack(spacing: 4) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<24, id: \.self) { hour in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "373737"))
                                .frame(height: barHeight(steps: hourlyStepsYesterday[hour], max: maxSteps, placeholder: true))
                            
                            if hourlyStepsToday[hour] > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "00CA48"))
                                    .frame(height: barHeight(steps: hourlyStepsToday[hour], max: maxSteps))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: chartHeight)
            
            HStack {
                ForEach(["0", "6", "12", "18", "24"], id: \.self) { label in
                    if label != "0" { Spacer() }
                    Text(label)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }
        }
    }
    
    // MARK: - Week Progress (line chart)
    private var weekProgressContent: some View {
        let dayLabels: [String] = weekStartsMonday ?
            ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"] :
            ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        
        let maxProgress = max(weekProgress.max() ?? 1.0, 1.0)
        
        return VStack(spacing: 4) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let stepX = width / 6
                
                // Goal line Y position (progress = 1.0)
                let goalY = height - (height * (1.0 / maxProgress))
                
                ZStack(alignment: .topLeading) {
                    // Vertical grid lines
                    ForEach(0..<7, id: \.self) { i in
                        Rectangle()
                            .fill(Color(hex: "1A1A1A"))
                            .frame(width: 1, height: height)
                            .offset(x: CGFloat(i) * stepX)
                    }
                    
                    // Goal dashed line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: goalY))
                        path.addLine(to: CGPoint(x: width, y: goalY))
                    }
                    .stroke(
                        Color(hex: "34C759").opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                    
                    // Green line + gradient fill
                    let points: [CGPoint] = (0..<7).map { i in
                        let x = CGFloat(i) * stepX
                        let prog = min(weekProgress[i], maxProgress)
                        let y = height - (height * (prog / maxProgress))
                        return CGPoint(x: x, y: y)
                    }
                    
                    // Gradient fill under line
                    Path { path in
                        guard !points.isEmpty else { return }
                        path.move(to: CGPoint(x: points[0].x, y: height))
                        path.addLine(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "34C759").opacity(0.3), Color(hex: "34C759").opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Green line
                    Path { path in
                        guard !points.isEmpty else { return }
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                    }
                    .stroke(Color(hex: "34C759"), lineWidth: 2)
                    
                    // Dots on each day
                    ForEach(0..<7, id: \.self) { i in
                        let x = CGFloat(i) * stepX
                        let prog = min(weekProgress[i], maxProgress)
                        let y = height - (height * (prog / maxProgress))
                        let isGoalMet = weekProgress[i] >= 1.0
                        
                        ZStack {
                            if i == currentDayIndex {
                                // Today — outer ring
                                Circle()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                                    .frame(width: 10, height: 10)
                            }
                            
                            Circle()
                                .fill(isGoalMet ? Color(hex: "34C759") : Color(hex: "B8B8B8"))
                                .frame(width: 6, height: 6)
                        }
                        .position(x: x, y: y)
                    }
                }
            }
            .frame(height: chartHeight)
            
            // Day labels
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.system(size: 10, weight: i == currentDayIndex ? .semibold : .regular, design: .monospaced))
                        .foregroundColor(i == currentDayIndex ? .white : Color(hex: "8E8E93"))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func barHeight(steps: Int, max: Int, placeholder: Bool = false) -> CGFloat {
        if steps == 0 {
            return placeholder ? 4 : 2
        }
        let ratio = CGFloat(steps) / CGFloat(max)
        return Swift.max(4, ratio * chartHeight)
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
