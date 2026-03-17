import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PlanningChatView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Plan")
                }
                .tag(0)

            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(2)
        }
        .tint(FlowLineTheme.accent)
    }
}

#Preview {
    MainTabView()
}
