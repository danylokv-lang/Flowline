import Foundation
import SwiftData

struct PlanSavingService {
    func save(plan: GeneratedPlan, for date: Date, context: ModelContext) throws {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let replaceWeek = plan.replaceWeek ?? false

        if replaceWeek {
            // Delete all DayPlans for the current week
            let weekday = calendar.component(.weekday, from: date)
            let daysToMonday = (weekday == 1) ? -6 : -(weekday - 2)
            let monday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: daysToMonday, to: date)!)
            let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!

            let weekDescriptor = FetchDescriptor<DayPlan>(
                predicate: #Predicate { $0.date >= monday && $0.date < nextMonday }
            )
            let weekPlans = try context.fetch(weekDescriptor)
            for plan in weekPlans {
                for block in plan.blocks {
                    context.delete(block)
                }
                context.delete(plan)
            }
        }

        // Group blocks by date
        var blocksByDate: [Date: [PlanBlock]] = [:]
        let fallbackDay = calendar.startOfDay(for: date)

        for planBlock in plan.blocks {
            let blockDate: Date
            if let dateStr = planBlock.date, let parsed = dateFormatter.date(from: dateStr) {
                blockDate = calendar.startOfDay(for: parsed)
            } else {
                blockDate = fallbackDay
            }
            blocksByDate[blockDate, default: []].append(planBlock)
        }

        // Save blocks per day
        for (day, planBlocks) in blocksByDate {
            let startOfDay = calendar.startOfDay(for: day)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let descriptor = FetchDescriptor<DayPlan>(
                predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
            )
            let existing = try context.fetch(descriptor)
            let dayPlan: DayPlan

            if let found = existing.first {
                // Replace blocks for this day
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

            for planBlock in planBlocks {
                guard let startParsed = timeFormatter.date(from: planBlock.startTime),
                      let endParsed = timeFormatter.date(from: planBlock.endTime) else {
                    continue
                }

                let startComponents = calendar.dateComponents([.hour, .minute], from: startParsed)
                let endComponents = calendar.dateComponents([.hour, .minute], from: endParsed)

                let startTime = calendar.date(bySettingHour: startComponents.hour!, minute: startComponents.minute!, second: 0, of: day)!
                let endTime = calendar.date(bySettingHour: endComponents.hour!, minute: endComponents.minute!, second: 0, of: day)!

                let category = Category(rawValue: planBlock.category)

                let block = ScheduleBlock(
                    title: planBlock.title,
                    category: category,
                    startTime: startTime,
                    endTime: endTime
                )
                dayPlan.blocks.append(block)
            }
        }

        try context.save()
    }

    func calendarContext(forWeekOf date: Date, context: ModelContext) throws -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysToMonday = (weekday == 1) ? -6 : -(weekday - 2)
        let monday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: daysToMonday, to: date)!)
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!

        let descriptor = FetchDescriptor<DayPlan>(
            predicate: #Predicate { $0.date >= monday && $0.date < nextMonday }
        )
        let plans = try context.fetch(descriptor)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE MMMM d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var lines: [String] = []
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: monday)!
            let startOfDay = calendar.startOfDay(for: day)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let dayPlan = plans.first { plan in
                let planDay = calendar.startOfDay(for: plan.date)
                return planDay >= startOfDay && planDay < endOfDay
            }

            let dayLabel = dayFormatter.string(from: day)
            if let plan = dayPlan, !plan.blocks.isEmpty {
                let sorted = plan.blocks.sorted { $0.startTime < $1.startTime }
                let items = sorted.map { block in
                    "\(block.title) \(timeFormatter.string(from: block.startTime))-\(timeFormatter.string(from: block.endTime))"
                }
                lines.append("\(dayLabel): \(items.joined(separator: ", "))")
            } else {
                lines.append("\(dayLabel): No schedule")
            }
        }

        return lines.joined(separator: "\n")
    }
}
