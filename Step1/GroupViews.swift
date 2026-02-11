//
//  GroupViews.swift
//  Step1
//
//  UI Components for Custom Groups
//

import SwiftUI
import UIKit

// MARK: - Group Tab Selector (Scrollable: FRIENDS | ALL STARS | Groups... | +)
struct GroupTabSelector: View {
    @ObservedObject var leaderboardManager: LeaderboardManager
    @ObservedObject var groupManager: GroupManager
    @Binding var selectedTab: GroupTab
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // FRIENDS tab (first)
                GroupTabButton(
                    title: "Friends",
                    iconSystemName: "person.2.fill",
                    isSelected: selectedTab == .friends
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .friends
                        leaderboardManager.showFriendsOnly = true
                    }
                }

                // ALL STARS tab (second)
                GroupTabButton(
                    title: "All Stars",
                    iconSystemName: "star.fill",
                    isSelected: selectedTab == .all
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .all
                        leaderboardManager.showFriendsOnly = false
                    }
                }

                // Custom groups
                ForEach(groupManager.userGroups) { group in
                    GroupTabButton(
                        title: group.name,
                        iconLetter: String(group.name.prefix(1)).uppercased(),
                        isSelected: selectedTab == .group(group.id)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .group(group.id)
                            groupManager.selectedGroupId = group.id
                        }
                    }
                }

                // New group button (+) — same style as GroupTabButton
                Button(action: {
                    showCreateGroup = true
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "3A3A3C"))
                                .frame(width: 24, height: 24)

                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("New")
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color(hex: "1A1A1A"))
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
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
    var iconSystemName: String? = nil
    var iconLetter: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Icon circle (24x24)
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "00A33A") : Color(hex: "3A3A3C"))
                        .frame(width: 24, height: 24)

                    if let systemName = iconSystemName {
                        Image(systemName: systemName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else if let letter = iconLetter {
                        Text(letter)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? Color(hex: "00A33A") : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isSelected ? Color(hex: "09200D") : Color(hex: "1A1A1A"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? Color(hex: "00A33A") : Color.clear, lineWidth: 1)
            )
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
                    GroupShareSheet(items: groupManager.getShareItems(for: group))
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
    @State private var showRenameSheet = false
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
                            HStack(spacing: 6) {
                                Text(group.name)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)

                                if group.isCreator {
                                    Button(action: { showRenameSheet = true }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color(hex: "8E8E93"))
                                    }
                                }
                            }

                            Text("\(group.memberCount) members")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "8E8E93"))

                            // Admin name
                            if let admin = leaderboardManager.users.first(where: { $0.id == group.adminId }) {
                                Text("Admin: \(admin.name)")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "8E8E93"))
                            }
                        }
                        
                        if !group.description.isEmpty {
                            Text(group.description)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "AEAEB2"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
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
                GroupShareSheet(items: groupManager.getShareItems(for: group))
            }
            .alert("Delete Group?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteGroup()
                }
            } message: {
                Text("Are you sure you want to delete '\(group.name)'? This will remove all members and cannot be undone.")
            }
            .sheet(isPresented: $showRenameSheet) {
                RenameGroupSheet(group: group, groupManager: groupManager) {
                    dismiss()
                }
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

// MARK: - Rename Group Sheet
struct RenameGroupSheet: View {
    let group: CustomGroup
    @ObservedObject var groupManager: GroupManager
    var onRenamed: (() -> Void)?
    @Environment(\.dismiss) var dismiss

    @State private var newName: String = ""
    @State private var isSaving = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "8E8E93"))

                        TextField("", text: $newName, prompt: Text(group.name).foregroundColor(Color(hex: "8E8E93")))
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color(hex: "1A1A1C"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                    }

                    Button(action: saveRename) {
                        ZStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(newName.isEmpty ? Color(hex: "3A3A3C") : Color(hex: "34C759"))
                        .cornerRadius(12)
                    }
                    .disabled(newName.isEmpty || isSaving)
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("Rename Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "34C759"))
                }
            }
        }
        .onAppear {
            newName = group.name
        }
    }

    private func saveRename() {
        guard !newName.isEmpty else { return }
        isSaving = true
        errorMessage = ""

        groupManager.updateGroup(groupId: group.id, name: newName, description: group.description) { error in
            isSaving = false
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                onRenamed?()
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
    let groupId: String
    @ObservedObject var groupManager: GroupManager
    @ObservedObject var leaderboardManager: LeaderboardManager
    var onUserTap: ((LeaderboardUser) -> Void)?

    @State private var members: [LeaderboardUser] = []
    @State private var isLoading = true
    @State private var showGroupDetail = false
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showRenameSheet = false

    /// Always read the latest group data from groupManager
    private var group: CustomGroup? {
        groupManager.userGroups.first(where: { $0.id == groupId })
    }

    var body: some View {
        if let group = group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .onAppear { loadMembers() }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Group info card (tappable → opens details)
                        Button(action: { showGroupDetail = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "00A33A").opacity(0.15))
                                        .frame(width: 40, height: 40)

                                    Text(String(group.name.prefix(1).uppercased()))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color(hex: "00A33A"))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)

                                    Text("\(group.memberCount) members")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "8E8E93"))
                                }

                                Spacer()

                                // Invite button (minimal)
                                Button(action: { showShareSheet = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Invite")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(Color(hex: "00A33A"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(hex: "09200D"))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(hex: "00A33A").opacity(0.3), lineWidth: 1)
                                    )
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "3A3A3C"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "1A1A1C"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                        // Table header
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

                        // Members list (same style as other leaderboard lists)
                        if members.isEmpty {
                            VStack(spacing: 12) {
                                Spacer().frame(height: 40)
                                Text("No members yet")
                                    .font(.system(size: 17))
                                    .foregroundColor(Color(hex: "8E8E93"))
                                Text("Invite friends to join this group")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "636366"))
                            }
                        } else {
                            ForEach(Array(members.enumerated()), id: \.element.id) { index, user in
                                NewLeaderboardRow(
                                    rank: index + 1,
                                    user: user,
                                    isCurrentUser: user.id == leaderboardManager.currentUserID,
                                    showDivider: index < members.count - 1
                                )
                                .onTapGesture { onUserTap?(user) }
                            }
                        }
                    }
                    .padding(.bottom, 160)
                }
                .sheet(isPresented: $showGroupDetail) {
                    GroupDetailsSheet(
                        group: group,
                        groupManager: groupManager,
                        leaderboardManager: leaderboardManager
                    )
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(items: groupManager.getShareItems(for: group))
                }
                .onChange(of: leaderboardManager.selectedDate) { _, _ in
                    loadMembers()
                }
                .onChange(of: leaderboardManager.selectedPeriod) { _, _ in
                    loadMembers()
                }
            }
        }
    }

    func loadMembers() {
        let dates = leaderboardManager.getDateRange()
        groupManager.getGroupMembers(groupId: groupId, dates: dates) { users in
            members = users.sorted { $0.steps > $1.steps }
            isLoading = false
        }
    }
}
