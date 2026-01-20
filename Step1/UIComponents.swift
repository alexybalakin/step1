//
//  UIComponents.swift
//  Step1
//
//  Created by Alex Balakin on 1/19/26.
//

import SwiftUI
import AuthenticationServices

// MARK: - Login View
struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "34C759"))
                    
                    Text("Step1")
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
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20))
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
                    
                    Text("Your data stays private and secure")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .padding(.top, 4)
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
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var healthManager: HealthManager
    @State private var showNameEditor = false
    @State private var showGoalEditor = false
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("Settings")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                    
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
                    
                    // Demo Users Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "DEMO USERS")
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                LeaderboardManager().generateDemoUsers()
                            }) {
                                Text("Generate Demo Users")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(hex: "34C759"))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                LeaderboardManager().deleteAllDemoUsers()
                            }) {
                                Text("Delete All Demo Users")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(hex: "FF9500"))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showNameEditor) {
            NameEditorView(authManager: authManager)
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorView(goal: $healthManager.dailyGoal)
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
                            authManager.userName = newName
                            UserDefaults.standard.set(newName, forKey: "userName")
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

// MARK: - Top Navigation (Updated to match Leaderboard style)
struct TopNavigationView: View {
    @Binding var selectedPeriod: Int
    @Binding var currentDate: Date
    let periods = ["Day", "Week", "Month"]
    
    var canGoForward: Bool {
        let calendar = Calendar.current
        let tomorrow: Date
        
        if selectedPeriod == 0 {
            tomorrow = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        } else if selectedPeriod == 1 {
            tomorrow = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        } else {
            tomorrow = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        
        return calendar.startOfDay(for: tomorrow) <= calendar.startOfDay(for: Date())
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        
        if selectedPeriod == 0 {
            if Calendar.current.isDateInToday(currentDate) {
                return "Сегодня"
            } else if Calendar.current.isDateInYesterday(currentDate) {
                return "Вчера"
            } else {
                formatter.dateFormat = "d MMMM"
                return formatter.string(from: currentDate)
            }
        } else if selectedPeriod == 1 {
            formatter.dateFormat = "d MMM"
            let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate))!
            let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
        } else {
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: currentDate)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Period selector - same style as Leaderboard
            HStack(spacing: 0) {
                ForEach(0..<periods.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = index
                        }
                    }) {
                        Text(periods[index])
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(selectedPeriod == index ? .white : Color(hex: "8E8E93"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                selectedPeriod == index ?
                                Color(hex: "2C2C2E") : Color.clear
                            )
                            .cornerRadius(8)
                    }
                }
            }
            .padding(2)
            .background(Color(hex: "1A1A1C"))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            
            HStack {
                Button(action: {
                    changeDate(by: -1)
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                }
                
                Spacer()
                
                Text(dateString)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    changeDate(by: 1)
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(canGoForward ? .white : Color(hex: "3A3A3C"))
                        .font(.system(size: 16))
                }
                .disabled(!canGoForward)
            }
            .padding(.horizontal, 30)
        }
    }
    
    func changeDate(by value: Int) {
        let calendar = Calendar.current
        let newDate: Date
        
        if selectedPeriod == 0 {
            newDate = calendar.date(byAdding: .day, value: value, to: currentDate) ?? currentDate
        } else if selectedPeriod == 1 {
            newDate = calendar.date(byAdding: .weekOfYear, value: value, to: currentDate) ?? currentDate
        } else {
            newDate = calendar.date(byAdding: .month, value: value, to: currentDate) ?? currentDate
        }
        
        if newDate <= Date() {
            withAnimation {
                currentDate = newDate
            }
        }
    }
}

// MARK: - Circular Progress (Steps on top, Goal on bottom)
struct CircularProgressView: View {
    let steps: Int
    let goal: Int
    let progress: Double
    let percentage: String
    let goalReached: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "1A1A1C"))
                .frame(width: 280, height: 280)
            
            Circle()
                .stroke(Color(hex: "2C2C2E"), lineWidth: 18)
                .frame(width: 280, height: 280)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color(hex: "34C759"),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1), value: progress)
            
            if progress > 0.9 {
                Circle()
                    .trim(from: 0, to: min((progress - 0.9) * 5, 0.3))
                    .stroke(
                        Color(hex: "FF9500"),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(-90 + 360 * progress))
                    .animation(.easeInOut(duration: 1), value: progress)
            }
            
            VStack(spacing: 8) {
                if goalReached {
                    HStack(spacing: 4) {
                        Text("🎯")
                            .font(.system(size: 14))
                        Text("GOAL REACHED")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                }
                
                // Steps number and label (on top)
                VStack(spacing: 4) {
                    Text("\(steps)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    
                    Text("Steps")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
                
                if goalReached {
                    Text(percentage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "34C759"))
                }
                
                // Goal (on bottom)
                if !goalReached {
                    Text("Goal \(goal.formatted())")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
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

// MARK: - Goal Editor
struct GoalEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var goal: Int
    @State private var newGoal = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("Set your daily step goal")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    VStack(spacing: 12) {
                        TextField("", text: $newGoal)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(height: 80)
                            .background(Color(hex: "1A1A1C"))
                            .cornerRadius(16)
                            .padding(.horizontal, 40)
                        Text("steps")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            QuickGoalButton(value: 5000, currentGoal: $newGoal)
                            QuickGoalButton(value: 8000, currentGoal: $newGoal)
                        }
                        HStack(spacing: 12) {
                            QuickGoalButton(value: 10000, currentGoal: $newGoal)
                            QuickGoalButton(value: 15000, currentGoal: $newGoal)
                        }
                    }.padding(.horizontal, 40)
                    Spacer()
                    Button {
                        if let v = Int(newGoal), v > 0 {
                            goal = v
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
                    }.padding(.horizontal, 40).padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "34C759"))
                }
            }
        }.onAppear { newGoal = "\(goal)" }
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
    @StateObject private var leaderboardManager = LeaderboardManager()
    @State private var selectedPeriod = 0
    let periods = ["Day", "Week", "Month"]
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                Text("Leaderboard")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                
                // Period Selector
                HStack(spacing: 0) {
                    ForEach(0..<periods.count, id: \.self) { index in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPeriod = index
                            }
                        }) {
                            Text(periods[index])
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(selectedPeriod == index ? .white : Color(hex: "8E8E93"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(
                                    selectedPeriod == index ?
                                    Color(hex: "2C2C2E") : Color.clear
                                )
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(2)
                .background(Color(hex: "1A1A1C"))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if leaderboardManager.users.isEmpty {
                    Spacer()
                    Text("No users yet")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "8E8E93"))
                    Text("Add demo users in Settings")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .padding(.top, 8)
                    Spacer()
                } else {
                    LeaderboardList(leaderboardManager: leaderboardManager)
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
    @State private var currentUserRowPosition: CGFloat? = nil
    @State private var scrollViewHeight: CGFloat = 0
    @State private var stickyRowHeight: CGFloat = 68
    
    var currentUserRank: Int? {
        leaderboardManager.getCurrentUserRank()
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
                        ForEach(Array(leaderboardManager.users.enumerated()), id: \.element.id) { index, user in
                            LeaderboardRow(
                                rank: index + 1,
                                user: user,
                                isCurrentUser: user.id == leaderboardManager.currentUserID
                            )
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
                    if let currentUser = leaderboardManager.users.first(where: { $0.id == leaderboardManager.currentUserID }) {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(hex: "3A3A3C"))
                                .frame(height: 0.5)
                            
                            LeaderboardRow(
                                rank: rank,
                                user: currentUser,
                                isCurrentUser: true
                            )
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
