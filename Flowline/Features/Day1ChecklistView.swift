
import SwiftUI

/// A small in-app checklist shown to new users for their first few days.
/// Automatically tracks progress and dismisses when all items are done.
struct Day1ChecklistView: View {
    @AppStorage("day1ChecklistDismissed")  private var dismissed = false
    @AppStorage("hasViewedCalendar")       private var hasViewedCalendar = false
    @AppStorage("hasUsedFocusTimer")       private var hasUsedFocusTimer = false
    @ObservedObject private var streak = StreakManager.shared

    private var hasFirstPlan: Bool { streak.totalPlansCreated > 0 }
    private var allDone: Bool { hasFirstPlan && hasViewedCalendar && hasUsedFocusTimer }

    var body: some View {
        if !dismissed {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Day 1 Setup")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(FlowLineTheme.secondTxt)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    Spacer()

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { dismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Items
                VStack(spacing: 0) {
                    checklistRow(
                        done: true,
                        icon: "person.fill",
                        label: "Profile set up"
                    )
                    Divider()
                        .background(FlowLineTheme.borderHi)
                        .padding(.leading, 40)
                    checklistRow(
                        done: hasFirstPlan,
                        icon: "sparkles",
                        label: "Create your first AI plan"
                    )
                    Divider()
                        .background(FlowLineTheme.borderHi)
                        .padding(.leading, 40)
                    checklistRow(
                        done: hasViewedCalendar,
                        icon: "calendar",
                        label: "View your calendar"
                    )
                    Divider()
                        .background(FlowLineTheme.borderHi)
                        .padding(.leading, 40)
                    checklistRow(
                        done: hasUsedFocusTimer,
                        icon: "timer",
                        label: "Try the Focus timer"
                    )
                }
                .padding(.bottom, 10)

                // Progress bar
                if !allDone {
                    let done = [true, hasFirstPlan, hasViewedCalendar, hasUsedFocusTimer].filter { $0 }.count
                    let progress = Double(done) / 4.0

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(FlowLineTheme.borderHi)
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient(
                                    colors: [FlowLineTheme.accent, Color(hex: "#c4b5fd")],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * progress, height: 3)
                                .animation(.easeInOut(duration: 0.4), value: progress)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                } else {
                    // All done — show celebration then auto-dismiss
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 13))
                        Text("Setup complete! You're ready to flow.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(FlowLineTheme.secondTxt)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.3)) { dismissed = true }
                        }
                    }
                }
            }
            .background(FlowLineTheme.tertiaryBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FlowLineTheme.borderHi, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func checklistRow(done: Bool, icon: String, label: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(done ? FlowLineTheme.accent.opacity(0.15) : FlowLineTheme.borderHi.opacity(0.5))
                    .frame(width: 24, height: 24)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(FlowLineTheme.accent)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                }
            }

            Text(label)
                .font(.system(size: 13, weight: done ? .medium : .regular))
                .foregroundColor(done ? FlowLineTheme.mainTxt : FlowLineTheme.secondTxt)
                .strikethrough(done, color: FlowLineTheme.secondTxt.opacity(0.4))

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
