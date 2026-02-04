import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var healthManager = HealthManager()
    @StateObject private var leaderboardManager = LeaderboardManager()
    @StateObject private var groupManager = GroupManager() // NEW: Group Manager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var selectedPeriod = 0
    @State private var currentDate = Date()
    @State private var showGoalEditor = false
    @State private var lastDate = Date()
    @State private var showSplash = true
    @State private var isOnboardingComplete = true // Default true, will check after auth
    @State private var midnightTimer: Timer?
    @State private var pendingGroupCode: String? = nil
    @State private var showJoinGroupAlert = false
    @State private var joinGroupResult: String = ""
    
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
            
            // Schedule midnight timer
            scheduleMidnightReset()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // App came to foreground - check if day changed
                checkDayChange()
                scheduleMidnightReset()
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth && !authManager.userID.isEmpty {
                isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding_\(authManager.userID)")
                selectedTab = 0 // Always show Main tab after login
                groupManager.loadUserGroups() // reload groups on auth change
                
                // Handle pending group join after login
                if let code = pendingGroupCode {
                    pendingGroupCode = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        groupManager.joinGroupFromLink(code: code) { result in
                            switch result {
                            case .success(let group):
                                joinGroupResult = "Joined \"\(group.name)\"!"
                                showJoinGroupAlert = true
                                selectedTab = 1
                            case .failure(let error):
                                joinGroupResult = error.localizedDescription
                                showJoinGroupAlert = true
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: authManager.userID) { _, userID in
            if !userID.isEmpty {
                isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding_\(userID)")
            }
        }
        .onOpenURL { url in
            // Handle deep link: steplease://join/XXXXXX
            if let code = groupManager.parseJoinURL(url) {
                if authManager.isAuthenticated && !authManager.isAnonymous {
                    // User is logged in — join immediately
                    groupManager.joinGroupFromLink(code: code) { result in
                        switch result {
                        case .success(let group):
                            joinGroupResult = "Joined \"\(group.name)\"!"
                            showJoinGroupAlert = true
                            selectedTab = 1 // Switch to leaderboard
                        case .failure(let error):
                            joinGroupResult = error.localizedDescription
                            showJoinGroupAlert = true
                        }
                    }
                } else {
                    // Save for after login
                    pendingGroupCode = code
                }
            }
        }
        .alert("Group", isPresented: $showJoinGroupAlert) {
            Button("OK") { }
        } message: {
            Text(joinGroupResult)
        }
    }
    
    private func checkDayChange() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(currentDate) {
            // Day has changed, reset to today
            currentDate = Date()
            healthManager.currentDate = Date()
            healthManager.loadDataForCurrentDate()
        }
    }
    
    private func scheduleMidnightReset() {
        midnightTimer?.invalidate()
        
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        let interval = tomorrow.timeIntervalSince(now) + 1 // 1 second after midnight
        
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            DispatchQueue.main.async {
                currentDate = Date()
                healthManager.currentDate = Date()
                healthManager.loadDataForCurrentDate()
                // Schedule next midnight reset
                scheduleMidnightReset()
            }
        }
    }
}

struct MainAppView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var healthManager: HealthManager
    @ObservedObject var leaderboardManager: LeaderboardManager
    @ObservedObject var groupManager: GroupManager
    @Binding var selectedTab: Int
    @Binding var selectedPeriod: Int
    @Binding var currentDate: Date
    @Binding var showGoalEditor: Bool
    @Binding var lastDate: Date
    @State private var isRefreshing = false
    @State private var previousPeriod: Int = 0
    @State private var showProfile = false
    @State private var showCelebration = false
    @State private var showMenu = false
    @State private var showShareSheet = false
    @State private var showStepsShareSheet = false
    
    let appStoreLink = "https://apps.apple.com/rs/app/steplease-step-tracker/id6758054873"
    
    var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(currentDate) {
            return "Today"
        } else if calendar.isDateInYesterday(currentDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM yy"
            formatter.locale = Locale(identifier: "en_US")
            return formatter.string(from: currentDate)
        }
    }
    
    /// How many days back from today (0 = today, 1 = yesterday, ... 6 = max)
    var dayOffset: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: currentDate)
        return calendar.dateComponents([.day], from: selected, to: today).day ?? 0
    }
    
    var canGoForward: Bool {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        return calendar.startOfDay(for: tomorrow) <= calendar.startOfDay(for: Date())
    }
    
    var canGoBack: Bool {
        return dayOffset < 6 // max 7 days total (0..6)
    }
    
    func changeDate(by value: Int) {
        let calendar = Calendar.current
        let newDate = calendar.date(byAdding: .day, value: value, to: currentDate) ?? currentDate
        let today = calendar.startOfDay(for: Date())
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        let target = calendar.startOfDay(for: newDate)
        
        if target >= sixDaysAgo && target <= today {
            withAnimation {
                currentDate = newDate
                healthManager.currentDate = newDate
                healthManager.loadDataForCurrentDate()
            }
        }
    }
    
    // FIX #5: Jump directly to today
    func jumpToToday() {
        let today = Date()
        withAnimation {
            currentDate = today
            healthManager.currentDate = today
            healthManager.loadDataForCurrentDate()
        }
    }
    
    @ViewBuilder
    func metricTiles(steps: Int, distanceOverride: Double? = nil, durationOverride: Int? = nil, caloriesOverride: Double? = nil) -> some View {
        let km = distanceOverride ?? (Double(steps) * 0.00075)
        let totalSec = durationOverride ?? Int((km / 5.0) * 3600.0)
        let cal = caloriesOverride ?? (Double(steps) * 0.045)
        
        HStack(spacing: 8) {
            StepMetricTile(
                title: "Distance",
                value: {
                    if healthManager.useMetric {
                        if km < 0.1 { return "\(Int(km * 1000)) m" }
                        return String(format: "%.1f km", km)
                    } else {
                        let miles = km * 0.621371
                        if miles < 0.1 { return "\(Int(miles * 5280)) ft" }
                        return String(format: "%.1f mi", miles)
                    }
                }()
            )
            
            StepMetricTile(
                title: "Time",
                value: {
                    let totalMinutes = totalSec / 60
                    let hours = totalMinutes / 60
                    let mins = totalMinutes % 60
                    let secs = totalSec % 60
                    if hours > 0 { return "\(hours)h \(mins)m" }
                    if totalMinutes > 0 { return "\(mins)m" }
                    return "\(secs)s"
                }()
            )
            
            StepMetricTile(
                title: "Calories",
                value: {
                    if cal < 1 && cal > 0 {
                        return String(format: "%.1f kcal", cal)
                    }
                    return "\(Int(cal)) kcal"
                }()
            )
        }
        .padding(.horizontal, 16)
    }
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0A")
                .ignoresSafeArea()
            
            if selectedTab == 0 {
                VStack(spacing: 0) {
                    TopNavigationView(
                        selectedPeriod: $selectedPeriod,
                        currentDate: $currentDate,
                        healthManager: healthManager,
                        authManager: authManager,
                        onProfileTap: { showProfile = true },
                        onMenuTap: { withAnimation(.easeOut(duration: 0.2)) { showMenu = true } }
                    )
                    .padding(.top, 8)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            if selectedPeriod == 0 {
                                // ===== DAY VIEW =====
                                CircularProgressView(
                                    steps: healthManager.steps,
                                    goal: healthManager.dailyGoal,
                                    progress: healthManager.progress,
                                    percentage: healthManager.percentageOverGoal,
                                    goalReached: healthManager.goalReached,
                                    dateLabel: dateLabel,
                                    isToday: Calendar.current.isDateInToday(currentDate),
                                    onGoBack: { changeDate(by: -1) },
                                    onGoForward: { changeDate(by: 1) },
                                    canGoBack: canGoBack,
                                    canGoForward: canGoForward,
                                    onJumpToToday: jumpToToday
                                )
                                .onTapGesture {
                                    showGoalEditor = true
                                }
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.82).combined(with: .opacity),
                                    removal: .scale(scale: 0.82).combined(with: .opacity)
                                ))
                                
                                // Distance / Time / Calories — daily
                                metricTiles(steps: healthManager.steps)
                                
                            } else if selectedPeriod == 1 {
                                // ===== WEEK VIEW =====
                                WeekSummaryView(
                                    totalSteps: healthManager.weekSummaryTotal,
                                    dailySteps: healthManager.weekSummaryDailySteps,
                                    dailyGoalMet: healthManager.weekSummaryDailyGoalMet,
                                    avgSteps: healthManager.weekSummaryAvg,
                                    prevAvgSteps: healthManager.weekSummaryPrevAvg,
                                    startDate: healthManager.weekSummaryStartDate,
                                    endDate: healthManager.weekSummaryEndDate,
                                    dailyGoal: healthManager.dailyGoal,
                                    weekStartsMonday: healthManager.weekStartsMonday
                                )
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                                .gesture(
                                    DragGesture(minimumDistance: 30)
                                        .onEnded { value in
                                            if value.translation.width > 50 {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    healthManager.fetchWeekSummary(offset: healthManager.weekOffset - 1)
                                                }
                                            } else if value.translation.width < -50 && healthManager.weekOffset < 0 {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    healthManager.fetchWeekSummary(offset: healthManager.weekOffset + 1)
                                                }
                                            }
                                        }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 1.15).combined(with: .opacity),
                                    removal: .scale(scale: 0.85).combined(with: .opacity)
                                ))
                                
                                // Distance / Time / Calories — weekly
                                metricTiles(
                                    steps: healthManager.weekSummaryTotal,
                                    distanceOverride: healthManager.weekSummaryTotalDistance,
                                    durationOverride: healthManager.weekSummaryTotalDuration,
                                    caloriesOverride: healthManager.weekSummaryTotalCalories
                                )
                                .padding(.top, 8)
                                
                            } else if selectedPeriod == 2 {
                                // ===== MONTH VIEW =====
                                MonthSummaryView(
                                    totalSteps: healthManager.monthSummaryTotal,
                                    dailySteps: healthManager.monthSummaryDailySteps,
                                    dailyGoalMet: healthManager.monthSummaryDailyGoalMet,
                                    avgSteps: healthManager.monthSummaryAvg,
                                    prevAvgSteps: healthManager.monthSummaryPrevAvg,
                                    monthDate: healthManager.monthSummaryMonth,
                                    dailyGoal: healthManager.dailyGoal,
                                    weekStartsMonday: healthManager.weekStartsMonday,
                                    canGoForward: healthManager.monthOffset < 0,
                                    onPrev: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            healthManager.fetchMonthSummary(offset: healthManager.monthOffset - 1)
                                        }
                                    },
                                    onNext: {
                                        if healthManager.monthOffset < 0 {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                healthManager.fetchMonthSummary(offset: healthManager.monthOffset + 1)
                                            }
                                        }
                                    }
                                )
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                                .gesture(
                                    DragGesture(minimumDistance: 30)
                                        .onEnded { value in
                                            if value.translation.width > 50 {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    healthManager.fetchMonthSummary(offset: healthManager.monthOffset - 1)
                                                }
                                            } else if value.translation.width < -50 && healthManager.monthOffset < 0 {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    healthManager.fetchMonthSummary(offset: healthManager.monthOffset + 1)
                                                }
                                            }
                                        }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 1.18).combined(with: .opacity),
                                    removal: .scale(scale: 0.82).combined(with: .opacity)
                                ))
                                
                                // Distance / Time / Calories — monthly
                                metricTiles(
                                    steps: healthManager.monthSummaryTotal,
                                    distanceOverride: healthManager.monthSummaryTotalDistance,
                                    durationOverride: healthManager.monthSummaryTotalDuration,
                                    caloriesOverride: healthManager.monthSummaryTotalCalories
                                )
                                .padding(.top, 8)
                            }
                            
                            // Progress Card (Day / Week / Quarter / Year)
                            ProgressCardView(
                                hourlyStepsToday: healthManager.hourlyStepsToday,
                                hourlyStepsYesterday: healthManager.hourlyStepsYesterday,
                                last7DaysProgress: healthManager.last7DaysProgress,
                                last7DaysLabels: healthManager.last7DaysLabels,
                                last7DaysGoalMet: healthManager.last7DaysGoalMet,
                                selectedDayOffset: dayOffset,
                                monthlyProgress: healthManager.yearProgress,
                                monthlyGoalMet: healthManager.yearGoalMet,
                                quarterProgress: healthManager.quarterProgress,
                                quarterGoalMet: healthManager.quarterGoalMet
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            // Streak + Best Day tiles
                            HStack(spacing: 8) {
                                StreakTile(
                                    currentStreak: healthManager.streakCount,
                                    maxStreak: healthManager.maxStreak
                                )
                                
                                BestDayTile(
                                    bestSteps: healthManager.bestDaySteps,
                                    bestDate: healthManager.bestDayDate
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 100)
                        }
                        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: selectedPeriod)
                    }
                    .refreshable {
                        await refreshData()
                    }
                    .onChange(of: selectedPeriod) { newPeriod in
                        if newPeriod == 1 {
                            healthManager.fetchWeekSummary(offset: 0)
                        } else if newPeriod == 2 {
                            healthManager.fetchMonthSummary(offset: 0)
                        }
                        previousPeriod = newPeriod
                    }
                    
                    Spacer()
                }
                .onAppear {
                    healthManager.currentDate = currentDate
                    healthManager.loadDataForCurrentDate()
                    lastDate = currentDate
                    // FIX #4: Check if goal was reached while app was closed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        healthManager.checkCelebrationOnLaunch()
                    }
                }
                .sheet(isPresented: $showProfile) {
                    ProfileView(authManager: authManager, healthManager: healthManager)
                }
                .onChange(of: healthManager.shouldShowCelebration) { shouldShow in
                    if shouldShow {
                        healthManager.shouldShowCelebration = false
                        // Show with delay (especially important when app just opened)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showCelebration = true
                            }
                        }
                    }
                }
                .overlay {
                    if showCelebration {
                        GoalCelebrationView(
                            steps: healthManager.steps,
                            goal: healthManager.dailyGoal,
                            isPresented: $showCelebration
                        )
                        .transition(.opacity)
                    }
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
            
            // Menu Overlay for main screen
            if showMenu && selectedTab == 0 {
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
        .preferredColorScheme(.dark)
        .onAppear {
            healthManager.requestAuthorization()
            
            // Start Live Activity
            if #available(iOS 16.1, *) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    healthManager.startLiveActivity()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if Calendar.current.isDateInToday(currentDate) {
                    leaderboardManager.updateCurrentUserSteps(healthManager.steps, name: authManager.userName)
                }
                healthManager.getHistoricalSteps(days: 30) { history in
                    leaderboardManager.syncHistoricalSteps(steps: history, name: authManager.userName)
                }
            }
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorView(goal: $healthManager.dailyGoal)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Join me on StePlease! Track your steps and compete with friends! \(appStoreLink)"])
        }
        .sheet(isPresented: $showStepsShareSheet) {
            ShareSheet(items: ["I walked \(healthManager.steps.formatted()) steps today! 🚶‍♂️ Track your steps with StePlease! \(appStoreLink)"])
        }
        .background(DateChangeHandler(currentDate: $currentDate, lastDate: $lastDate, healthManager: healthManager))
        .onChange(of: healthManager.steps) { _, newSteps in
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
