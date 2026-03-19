import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        TabView(selection: $selectedTab) {
            PlanningChatView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Plan", systemImage: "sparkles")
                }
                .tag(0)

            CalendarView()
                .tabItem {
                    Label("Week", systemImage: "calendar")
                }
                .tag(1)

            FocusTimerView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
                .tag(2)
        }
        .tint(FlowLineTheme.accent)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { openSettings() } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(FlowLineTheme.secondTxt)
                }
                .help("Settings  ⌘,")
            }
        }
    }
}

#Preview {
    MainTabView()
}
