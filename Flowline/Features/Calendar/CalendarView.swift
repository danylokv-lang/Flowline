import SwiftUI

struct CalendarView: View {
    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Calendar")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(FlowLineTheme.mainTxt)
                Text("Your day plan will appear here")
                    .foregroundColor(FlowLineTheme.secondTxt)
            }
        }
    }
}

#Preview {
    CalendarView()
}
