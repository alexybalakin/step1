import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var healthManager = HealthManager()
    @StateObject private var leaderboardManager = LeaderboardManager()
    @StateObject private var groupManager = GroupManager() // NEW: Group Manager
    @State private var selectedTab = 0
    @State private var selectedPeriod = 0
    @State private var currentDate = Date()
    @State private var showGoalEditor = false
    @State private var lastDate = Date()
    @State private var showSplash = true
    @State private var isOnboardingComplete = true // Default true, will check after auth
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            } else if !authManager.isAuthenticated {
                LoginView(authManager: authManager)
                    .transition(.opacity)
            } else if !isOnboardingComplete {
                OnboardingView(healthManager: healthManager, isOnboardingComplete: $isOnboardingComplete, userID: authManager.userID)
                    .transition(.opacity)
            } else {
                MainAppView(
                    authManager: authManager,
                    healthManager: healthManager,
                    leaderboardManager: leaderboardManager,
                    groupManager: groupManager, // NEW: pass groupManager
                    selectedTab: $selectedTab,
                    selectedPeriod: $selectedPeriod,
                    currentDate: $currentDate,
                    showGoalEditor: $showGoalEditor,
                    lastDate: $lastDate
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: isOnboardingComplete)
        .onAppear {
            // Check onboarding status on appear if already authenticated
            if authManager.isAuthenticated && !authManager.userID.isEmpty {
                isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding_\(authManager.userID)")
            }
            
            // Hide splash after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSplash = false
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth && !authManager.userID.isEmpty {
                isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding_\(authManager.userID)")
                selectedTab = 0 // Always show Main tab after login
                groupManager.loadUserGroups() // NEW: reload groups on auth change
            }
        }
        .onChange(of: authManager.userID) { _, userID in
            if !userID.isEmpty {
                isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding_\(userID)")
            }
        }
    }
}

struct MainAppView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var healthManager: HealthManager
    @ObservedObject var leaderboardManager: LeaderboardManager
    @ObservedObject var groupManager: GroupManager // NEW: Group Manager
    @Binding var selectedTab: Int
    @Binding var selectedPeriod: Int
    @Binding var currentDate: Date
    @Binding var showGoalEditor: Bool
    @Binding var lastDate: Date
    @State private var isRefreshing = false
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            if selectedTab == 0 {
                VStack(spacing: 0) {
                    TopNavigationView(
                        selectedPeriod: $selectedPeriod,
                        currentDate: $currentDate,
                        healthManager: healthManager
                    )
                    .padding(.top, 8)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            CircularProgressView(
                                steps: healthManager.steps,
                                goal: healthManager.dailyGoal,
                                progress: healthManager.progress,
                                percentage: healthManager.percentageOverGoal,
                                goalReached: healthManager.goalReached
                            )
                            .padding(.top, 34)
                            .padding(.bottom, 14)
                            .onTapGesture {
                                showGoalEditor = true
                            }
                            
                            HStack(spacing: 12) {
                                StatCard(
                                    title: "DISTANCE",
                                    value: String(format: "%.1f", healthManager.distance),
                                    unit: "km",
                                    percentage: healthManager.distanceChange >= 0 ?
                                        String(format: "+ %.1f%%", healthManager.distanceChange) :
                                        String(format: "%.1f%%", healthManager.distanceChange),
                                    isPositive: healthManager.distanceChange >= 0
                                )
                                
                                StatCard(
                                    title: "DURATION",
                                    value: "\(healthManager.duration)",
                                    unit: "min",
                                    percentage: healthManager.durationChange >= 0 ?
                                        String(format: "+ %.1f%%", healthManager.durationChange) :
                                        String(format: "%.1f%%", healthManager.durationChange),
                                    isPositive: healthManager.durationChange >= 0
                                )
                            }
                            .padding(.horizontal, 20)
                            
                            StreakView(
                                streakCount: healthManager.streakCount,
                                weekStreak: healthManager.weekStreak,
                                weekProgress: healthManager.weekProgress,
                                currentDate: currentDate
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                    }
                    .refreshable {
                        await refreshData()
                    }
                    
                    Spacer()
                }
                .onAppear {
                    healthManager.currentDate = currentDate
                    healthManager.loadDataForCurrentDate()
                    lastDate = currentDate
                }
            } else if selectedTab == 1 {
                // Leaderboard - only for logged in users
                if authManager.isAnonymous {
                    LeaderboardLockedView(authManager: authManager)
                } else {
                    TopLeaderboardView(
                        leaderboardManager: leaderboardManager,
                        authManager: authManager,
                        groupManager: groupManager
                    )
                }
            } else if selectedTab == 2 {
                // Awards (placeholder for now)
                AwardsView()
            } else if selectedTab == 3 {
                // Settings
                SettingsView(authManager: authManager, healthManager: healthManager, leaderboardManager: leaderboardManager)
            }
            
            VStack {
                Spacer()
                BottomNavigationView(selectedTab: $selectedTab)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            healthManager.requestAuthorization()
            // Sync steps after delay to ensure data is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if Calendar.current.isDateInToday(currentDate) {
                    leaderboardManager.updateCurrentUserSteps(healthManager.steps, name: authManager.userName)
                }
                // Sync historical steps (last 30 days)
                healthManager.getHistoricalSteps(days: 30) { history in
                    leaderboardManager.syncHistoricalSteps(steps: history, name: authManager.userName)
                }
            }
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorView(goal: $healthManager.dailyGoal)
        }
        .background(DateChangeHandler(currentDate: $currentDate, lastDate: $lastDate, healthManager: healthManager))
        // Sync steps to leaderboard when they change
        .onChange(of: healthManager.steps) { _, newSteps in
            // Sync today's steps (including 0)
            if Calendar.current.isDateInToday(currentDate) {
                leaderboardManager.updateCurrentUserSteps(newSteps, name: authManager.userName)
            }
        }
    }
    
    func refreshData() async {
        healthManager.currentDate = currentDate
        healthManager.loadDataForCurrentDate()
        // Small delay to show refresh animation
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}

struct DateChangeHandler: View {
    @Binding var currentDate: Date
    @Binding var lastDate: Date
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        Color.clear
            .onChange(of: currentDate) { _, newValue in
                healthManager.currentDate = newValue
                healthManager.loadDataForCurrentDate()
                lastDate = newValue
            }
    }
}

#Preview {
    ContentView()
}
