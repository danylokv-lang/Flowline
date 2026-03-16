import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            PlanningChatView()
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Plan")
                }

            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
        }
        .tint(FlowLineTheme.accent)
    }
}

#Preview {
    MainTabView()
}
