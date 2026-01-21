import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var healthManager = HealthManager()
    @StateObject private var leaderboardManager = LeaderboardManager()
    @State private var selectedTab = 0
    @State private var selectedPeriod = 0
    @State private var currentDate = Date()
    @State private var showGoalEditor = false
    @State private var lastDate = Date()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainAppView(
                    authManager: authManager,
                    healthManager: healthManager,
                    leaderboardManager: leaderboardManager,
                    selectedTab: $selectedTab,
                    selectedPeriod: $selectedPeriod,
                    currentDate: $currentDate,
                    showGoalEditor: $showGoalEditor,
                    lastDate: $lastDate
                )
            } else {
                LoginView(authManager: authManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

struct MainAppView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var healthManager: HealthManager
    @ObservedObject var leaderboardManager: LeaderboardManager
    @Binding var selectedTab: Int
    @Binding var selectedPeriod: Int
    @Binding var currentDate: Date
    @Binding var showGoalEditor: Bool
    @Binding var lastDate: Date
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            if selectedTab == 0 {
                VStack(spacing: 0) {
                    TopNavigationView(
                        selectedPeriod: $selectedPeriod,
                        currentDate: $currentDate
                    )
                    .padding(.top, 20)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ZStack {
                                CircularProgressView(
                                    steps: healthManager.steps,
                                    goal: healthManager.dailyGoal,
                                    progress: healthManager.progress,
                                    percentage: healthManager.percentageOverGoal,
                                    goalReached: healthManager.goalReached
                                )
                                
                                VStack {
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "8E8E93"))
                                        .padding(.bottom, 35)
                                }
                                .frame(height: 280)
                            }
                            .padding(.top, 30)
                            .padding(.bottom, 8)
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
                    
                    Spacer()
                }
                .onAppear {
                    healthManager.currentDate = currentDate
                    healthManager.loadDataForCurrentDate()
                    lastDate = currentDate
                }
            } else if selectedTab == 1 {
                TopLeaderboardView(leaderboardManager: leaderboardManager)
            } else if selectedTab == 2 {
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
