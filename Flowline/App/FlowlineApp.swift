/*
    Flowline
    Created by Danylo Kov: 15/03/26
*/  

import SwiftUI
import SwiftData

@main
struct FlowlineApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FlowTask.self,
            ScheduleBlock.self,
            DayPlan.self,
            UserProfile.self,
            ChatMessage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
