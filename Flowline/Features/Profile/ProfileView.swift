import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var selectedProfileID: PersistentIdentifier?
    @State private var showDeleteConfirm = false
    @State private var profileToDelete: UserProfile?
    @State private var showNewProfile = false

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROFILES")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(4)
                        .foregroundColor(FlowLineTheme.secondTxt)
                    Text("Who's planning today?")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(FlowLineTheme.mainTxt)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(FlowLineTheme.borderHi)
                    .frame(height: 0.5)

                if profiles.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("No profiles yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(FlowLineTheme.secondTxt)
                        Text("Add one to get started")
                            .font(.system(size: 13))
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(profiles) { profile in
                                profileCard(profile)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }

                // ── New Profile Button ────────────────────────────────
                Rectangle()
                    .fill(FlowLineTheme.borderHi)
                    .frame(height: 0.5)

                Button {
                    showNewProfile = true
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(FlowLineTheme.accent.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(FlowLineTheme.accent)
                        }
                        Text("New Profile")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FlowLineTheme.accent)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
        }
        .alert("Delete Profile?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    if selectedProfileID == profile.persistentModelID {
                        selectedProfileID = nil
                    }
                    modelContext.delete(profile)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This profile will be permanently removed.")
        }
        .sheet(isPresented: $showNewProfile) {
            OnboardingView(isInitialOnboarding: false)
        }
        .onAppear {
            if selectedProfileID == nil, let first = profiles.first {
                selectedProfileID = first.persistentModelID
            }
        }
    }

    // MARK: - Profile Card

    private func profileCard(_ profile: UserProfile) -> some View {
        let isSelected = selectedProfileID == profile.persistentModelID
        let initials = String(profile.name.prefix(1)).uppercased()
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.timeStyle = .short
            return f
        }()

        return HStack(spacing: 14) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(isSelected ? FlowLineTheme.accent : FlowLineTheme.tertiaryBg)
                    .frame(width: 48, height: 48)
                Text(initials)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(isSelected ? FlowLineTheme.mainBg : FlowLineTheme.secondTxt)
            }
            .animation(.easeInOut(duration: 0.2), value: isSelected)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    if isSelected {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .heavy))
                            .tracking(1)
                            .foregroundColor(FlowLineTheme.mainBg)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FlowLineTheme.accent)
                            .clipShape(Capsule())
                    }
                }

                Text("\(timeFormatter.string(from: profile.wakeTime)) – \(timeFormatter.string(from: profile.sleepTime))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(FlowLineTheme.secondTxt)

                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .font(.system(size: 11))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                if !isSelected {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProfileID = profile.persistentModelID
                        }
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    profileToDelete = profile
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(FlowLineTheme.secondBg.opacity(isSelected ? 0.9 : 0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isSelected ? FlowLineTheme.accent.opacity(0.3) : FlowLineTheme.border,
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProfileID = profile.persistentModelID
            }
        }
    }
}

#Preview {
    ProfileView()
}
