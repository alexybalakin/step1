//
//  GroupViews.swift
//  Step1
//
//  UI Components for Custom Groups
//

import SwiftUI
import UIKit

// MARK: - Group Tab Selector (Scrollable: ALL | FRIENDS | Groups... | +)
struct GroupTabSelector: View {
    @ObservedObject var leaderboardManager: LeaderboardManager
    @ObservedObject var groupManager: GroupManager
    @Binding var selectedTab: GroupTab
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // ALL tab
                GroupTabButton(
                    title: "ALL",
                    count: leaderboardManager.users.count,
                    isSelected: selectedTab == .all
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .all
                        leaderboardManager.showFriendsOnly = false
                    }
                }
                
                // FRIENDS tab
                GroupTabButton(
                    title: "FRIENDS",
                    count: leaderboardManager.friends.count,
                    isSelected: selectedTab == .friends
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .friends
                        leaderboardManager.showFriendsOnly = true
                    }
                }
                
                // Custom groups
                ForEach(groupManager.userGroups) { group in
                    GroupTabButton(
                        title: group.name.uppercased(),
                        count: group.memberCount,
                        isSelected: selectedTab == .group(group.id)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .group(group.id)
                            groupManager.selectedGroupId = group.id
                        }
                    }
                }
                
                // Add group button (+)
                Button(action: {
                    showCreateGroup = true
                }) {
                    Text("+")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "8E8E93"))
                        .frame(width: 40, height: 32)
                        .background(Color.clear)
                        .cornerRadius(8)
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 0)
        }
        .background(Color(hex: "1A1A1C"))
        .cornerRadius(8)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupSheet(groupManager: groupManager, showJoinGroup: $showJoinGroup)
        }
        .sheet(isPresented: $showJoinGroup) {
            JoinGroupSheet(groupManager: groupManager)
        }
    }
}

// MARK: - Group Tab Button
struct GroupTabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text("(\(count))")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .foregroundColor(isSelected ? .white : Color(hex: "8E8E93"))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(isSelected ? Color(hex: "3A3A3C") : Color.clear)
            .cornerRadius(8)
        }
    }
}

// MARK: - Group Tab Enum
enum GroupTab: Equatable {
    case all
    case friends
    case group(String)
    
    static func == (lhs: GroupTab, rhs: GroupTab) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all): return true
        case (.friends, .friends): return true
        case (.group(let id1), .group(let id2)): return id1 == id2
        default: return false
        }
    }
}

// MARK: - Create Group Sheet
struct CreateGroupSheet: View {
    @ObservedObject var groupManager: GroupManager
    @Binding var showJoinGroup: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isCreating = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: "34C759").opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "34C759"))
                        }
                        .padding(.top, 32)
                        
                        Text("Create a Group")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Compete with friends, colleagues, or family")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 16) {
                            // Group Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Group Name")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "8E8E93"))
                                
                                TextField("", text: $groupName, prompt: Text("e.g. Office Challenge").foregroundColor(Color(hex: "8E8E93")))
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(Color(hex: "1A1A1C"))
                                    .cornerRadius(12)
                            }
                            
                            // Group Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description (optional)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "8E8E93"))
                                
                                TextField("", text: $groupDescription, prompt: Text("What's this group about?").foregroundColor(Color(hex: "8E8E93")))
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(Color(hex: "1A1A1C"))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }
                        
                        // Create button
                        Button(action: createGroup) {
                            ZStack {
                                if isCreating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Create Group")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(groupName.isEmpty ? Color(hex: "3A3A3C") : Color(hex: "34C759"))
                            .cornerRadius(12)
                        }
                        .disabled(groupName.isEmpty || isCreating)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Join group link
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showJoinGroup = true
                            }
                        }) {
                            Text("Already have a code? Join a group")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "34C759"))
                        }
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "34C759"))
                }
            }
        }
    }
    
    private func createGroup() {
        guard !groupName.isEmpty else { return }
        
        isCreating = true
        errorMessage = ""
        
        groupManager.createGroup(name: groupName, description: groupDescription) { result in
            isCreating = false
            
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Join Group Sheet
struct JoinGroupSheet: View {
    @ObservedObject var groupManager: GroupManager
    @Environment(\.dismiss) var dismiss
    
    @State private var joinCode = ""
    @State private var isJoining = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: "007AFF").opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "link")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "007AFF"))
                        }
                        .padding(.top, 32)
                        
                        Text("Join a Group")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Enter the 6-digit code from a friend")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .multilineTextAlignment(.center)
                        
                        // Join code input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Group Code")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "8E8E93"))
                            
                            TextField("", text: $joinCode, prompt: Text("e.g. ABC123").foregroundColor(Color(hex: "8E8E93")))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .textCase(.uppercase)
                                .padding(16)
                                .background(Color(hex: "1A1A1C"))
                                .cornerRadius(12)
                                .onChange(of: joinCode) { oldValue, newValue in
                                    joinCode = String(newValue.prefix(6)).uppercased()
                                }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }
                        
                        // Join button
                        Button(action: joinGroup) {
                            ZStack {
                                if isJoining {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Join Group")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(joinCode.count == 6 ? Color(hex: "007AFF") : Color(hex: "3A3A3C"))
                            .cornerRadius(12)
                        }
                        .disabled(joinCode.count != 6 || isJoining)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "007AFF"))
                }
            }
        }
    }
    
    private func joinGroup() {
        guard joinCode.count == 6 else { return }
        
        isJoining = true
        errorMessage = ""
        
        groupManager.joinGroup(inviteCode: joinCode) { result in
            isJoining = false
            
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Group Details Sheet
struct GroupDetailsSheet: View {
    let group: CustomGroup
    @ObservedObject var groupManager: GroupManager
    @ObservedObject var leaderboardManager: LeaderboardManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Group icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: "34C759").opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Text(String(group.name.prefix(1).uppercased()))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(Color(hex: "34C759"))
                        }
                        .padding(.top, 32)
                        
                        VStack(spacing: 8) {
                            Text(group.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\(group.memberCount) members")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "8E8E93"))
                        }
                        
                        if !group.description.isEmpty {
                            Text(group.description)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "AEAEB2"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        // Join code section
                        VStack(spacing: 12) {
                            Text("Invite Code")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "8E8E93"))
                            
                            HStack(spacing: 12) {
                                Text(group.joinCode)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .tracking(4)
                                
                                Button(action: {
                                    UIPasteboard.general.string = group.joinCode
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(hex: "34C759"))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color(hex: "1A1A1C"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Share button
                        Button(action: { showShareSheet = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Share Invite")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "34C759"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Delete button (only for creator)
                        if group.isCreator {
                            Button(action: { showDeleteConfirmation = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Delete Group")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "1A1A1C"))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "34C759"))
                }
            }
            .sheet(isPresented: $showShareSheet) {
                GroupShareSheet(items: [
                    "Join my step challenge group '\(group.name)' using code: \(group.joinCode)"
                ])
            }
            .alert("Delete Group?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteGroup()
                }
            } message: {
                Text("Are you sure you want to delete '\(group.name)'? This will remove all members and cannot be undone.")
            }
        }
    }
    
    private func deleteGroup() {
        isDeleting = true
        
        groupManager.deleteGroup(groupId: group.id) { error in
            isDeleting = false
            
            if error == nil {
                dismiss()
            }
        }
    }
}

// MARK: - Group Share Sheet
struct GroupShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Group Leaderboard View
struct GroupLeaderboardView: View {
    let group: CustomGroup
    @ObservedObject var groupManager: GroupManager
    @ObservedObject var leaderboardManager: LeaderboardManager
    var onUserTap: ((LeaderboardUser) -> Void)?
    var onGroupTap: (() -> Void)?
    
    @State private var members: [LeaderboardUser] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
            } else if members.isEmpty {
                VStack {
                    Spacer()
                    Text("No members yet")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "8E8E93"))
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Group info card (tappable)
                        Button(action: { onGroupTap?() }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "34C759").opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    
                                    Text(String(group.name.prefix(1).uppercased()))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color(hex: "34C759"))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("\(group.memberCount) members")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "8E8E93"))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "3A3A3C"))
                            }
                            .padding(16)
                            .background(Color(hex: "1A1A1C"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                        
                        // Members list
                        ForEach(Array(members.enumerated()), id: \.element.id) { index, user in
                            LeaderboardRow(
                                rank: index + 1,
                                user: user,
                                isCurrentUser: user.id == leaderboardManager.currentUserID
                            )
                            .onTapGesture {
                                onUserTap?(user)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            
            // Share button
            Button(action: { onGroupTap?() }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
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
            .padding(.trailing, 20)
            .padding(.bottom, 100)
        }
        .onAppear {
            loadMembers()
        }
    }
    
    func loadMembers() {
        groupManager.getGroupMembers(groupId: group.id) { users in
            members = users.sorted { $0.steps > $1.steps }
            isLoading = false
        }
    }
}
