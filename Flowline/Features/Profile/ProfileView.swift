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

            VStack(spacing: 20) {
                Text("Profiles")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(FlowLineTheme.mainTxt)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                if profiles.isEmpty {
                    Spacer()
                    Text("No profiles yet")
                        .foregroundColor(FlowLineTheme.secondTxt)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(profiles) { profile in
                                profileCard(profile)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Button {
                    showNewProfile = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Profile")
                    }
                    .bold()
                    .foregroundColor(FlowLineTheme.mainBg)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(FlowLineTheme.accent)
                    .cornerRadius(12)
                }
                .padding(.bottom, 20)
            }
            .padding(.top, 20)
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
            // Auto-select first profile if none selected
            if selectedProfileID == nil, let first = profiles.first {
                selectedProfileID = first.persistentModelID
            }
        }
    }

    private func profileCard(_ profile: UserProfile) -> some View {
        let isSelected = selectedProfileID == profile.persistentModelID

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profile.name)
                    .font(.headline)
                    .foregroundColor(FlowLineTheme.mainTxt)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(FlowLineTheme.accent)
                }
            }

            let formatter = DateFormatter()
            let _ = formatter.timeStyle = .short
            Text("Wake: \(formatter.string(from: profile.wakeTime)) — Sleep: \(formatter.string(from: profile.sleepTime))")
                .font(.caption)
                .foregroundColor(FlowLineTheme.secondTxt)

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.caption)
                    .foregroundColor(FlowLineTheme.secondTxt.opacity(0.8))
                    .lineLimit(2)
            }

            HStack {
                Button {
                    selectedProfileID = profile.persistentModelID
                } label: {
                    Text(isSelected ? "Active" : "Select")
                        .font(.caption)
                        .foregroundColor(isSelected ? FlowLineTheme.accent : FlowLineTheme.mainTxt)
                }

                Spacer()

                Button {
                    profileToDelete = profile
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(isSelected ? FlowLineTheme.secondBg.opacity(0.5) : FlowLineTheme.secondBg.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? FlowLineTheme.accent.opacity(0.5) : .clear, lineWidth: 1)
        )
    }
}

#Preview {
    ProfileView()
}
