import Foundation
import SwiftData

struct PlanSavingService {
    func save(plan: GeneratedPlan, for date: Date, context: ModelContext) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Find existing DayPlan for this date
        let descriptor = FetchDescriptor<DayPlan>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let existing = try context.fetch(descriptor)
        let dayPlan: DayPlan

        if let found = existing.first {
            // Delete old blocks
            for block in found.blocks {
                context.delete(block)
            }
            found.blocks = []
            found.status = .planned
            found.aiNotes = plan.summary
            dayPlan = found
        } else {
            dayPlan = DayPlan(date: startOfDay)
            dayPlan.aiNotes = plan.summary
            context.insert(dayPlan)
        }

        // Convert PlanBlocks to ScheduleBlocks
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        for planBlock in plan.blocks {
            guard let startParsed = timeFormatter.date(from: planBlock.startTime),
                  let endParsed = timeFormatter.date(from: planBlock.endTime) else {
                continue
            }

            let startComponents = calendar.dateComponents([.hour, .minute], from: startParsed)
            let endComponents = calendar.dateComponents([.hour, .minute], from: endParsed)

            let startTime = calendar.date(bySettingHour: startComponents.hour!, minute: startComponents.minute!, second: 0, of: date)!
            let endTime = calendar.date(bySettingHour: endComponents.hour!, minute: endComponents.minute!, second: 0, of: date)!

            let category = Category(rawValue: planBlock.category)

            let block = ScheduleBlock(
                title: planBlock.title,
                category: category,
                startTime: startTime,
                endTime: endTime
            )
            dayPlan.blocks.append(block)
        }

        try context.save()
    }
}
