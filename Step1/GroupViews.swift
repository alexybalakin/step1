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
    @State private var createdGroup: CustomGroup? = nil
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if let group = createdGroup {
                            // Success state — show share
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "34C759").opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(hex: "34C759"))
                            }
                            .padding(.top, 32)
                            
                            Text("Group Created!")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Share the link with friends to invite them")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "8E8E93"))
                                .multilineTextAlignment(.center)
                            
                            Button(action: { showShareSheet = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Share Invite Link")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "34C759"))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            
                            Button(action: { dismiss() }) {
                                Text("Done")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(Color(hex: "8E8E93"))
                            }
                            .padding(.top, 8)
                            
                        } else {
                            // Create form
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
                            
                            Button(action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showJoinGroup = true
                                }
                            }) {
                                Text("Have an invite link? Join a group")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(hex: "34C759"))
                            }
                            .padding(.top, 8)
                        }
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
            .sheet(isPresented: $showShareSheet) {
                if let group = createdGroup {
                    GroupShareSheet(items: [
                        groupManager.getShareText(for: group)
                    ])
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
            case .success(let group):
                withAnimation {
                    createdGroup = group
                }
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
    
    @State private var inputText = ""
    @State private var isJoining = false
    @State private var errorMessage = ""
    
    private var extractedCode: String {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try: steplease://join/XXXXXX
        if text.contains("steplease://join/") {
            let parts = text.components(separatedBy: "steplease://join/")
            if let last = parts.last {
                let code = String(last.prefix(6)).uppercased()
                return code
            }
        }
        // Try: code=XXXXXX
        if let range = text.range(of: "code=") {
            let code = String(text[range.upperBound...]).prefix(6).uppercased()
            return String(code)
        }
        // Raw code input
        return String(text.prefix(6)).uppercased()
    }
    
    private var isValidCode: Bool {
        extractedCode.count == 6
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
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
                        
                        Text("Paste the invite link or enter the code")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "8E8E93"))
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invite Link or Code")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "8E8E93"))
                            
                            TextField("", text: $inputText, prompt: Text("Paste link or enter code").foregroundColor(Color(hex: "8E8E93")))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color(hex: "1A1A1C"))
                                .cornerRadius(12)
                            
                            if isValidCode && inputText.count > 6 {
                                Text("Code detected: \(extractedCode)")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "34C759"))
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
                            .background(isValidCode ? Color(hex: "007AFF") : Color(hex: "3A3A3C"))
                            .cornerRadius(12)
                        }
                        .disabled(!isValidCode || isJoining)
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
        guard isValidCode else { return }
        
        isJoining = true
        errorMessage = ""
        
        groupManager.joinGroup(inviteCode: extractedCode) { result in
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
    @State private var linkCopied = false
    
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
                        
                        // Share link section
                        VStack(spacing: 12) {
                            Text("Invite Friends")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "8E8E93"))
                            
                            // Invite link display
                            HStack(spacing: 12) {
                                Image(systemName: "link")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "34C759"))
                                
                                Text("steplease://join/\(group.joinCode)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(Color(hex: "AEAEB2"))
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Button(action: {
                                    UIPasteboard.general.string = groupManager.getShareText(for: group)
                                    linkCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        linkCopied = false
                                    }
                                }) {
                                    Text(linkCopied ? "Copied!" : "Copy")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(linkCopied ? .white : Color(hex: "34C759"))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(linkCopied ? Color(hex: "34C759") : Color(hex: "34C759").opacity(0.15))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
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
                                Text("Share Invite Link")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "34C759"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Leave / Delete
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
                        } else {
                            Button(action: {
                                groupManager.leaveGroup(groupId: group.id) { _ in
                                    dismiss()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Leave Group")
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
                    groupManager.getShareText(for: group)
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
