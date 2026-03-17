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

        // Fetch all plans once
        let allPlans = try context.fetch(FetchDescriptor<DayPlan>())

        if replaceWeek {
            let weekday = calendar.component(.weekday, from: date)
            let daysToMonday = (weekday == 1) ? -6 : -(weekday - 2)
            let monday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: daysToMonday, to: date)!)
            let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!

            let weekPlans = allPlans.filter { $0.date >= monday && $0.date < nextMonday }
            for weekPlan in weekPlans {
                for block in weekPlan.blocks {
                    context.delete(block)
                }
                context.delete(weekPlan)
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

        // Re-fetch after potential deletions
        let freshPlans = try context.fetch(FetchDescriptor<DayPlan>())

        // Save blocks per day
        for (day, planBlocks) in blocksByDate {
            let startOfDay = calendar.startOfDay(for: day)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let existing = freshPlans.filter { p in
                let planDay = calendar.startOfDay(for: p.date)
                return planDay >= startOfDay && planDay < endOfDay
            }

            let dayPlan: DayPlan
            if let found = existing.first {
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
                    print("⚠️ Could not parse time for block:", planBlock.title, planBlock.startTime, planBlock.endTime)
                    continue
                }

                let startComponents = calendar.dateComponents([.hour, .minute], from: startParsed)
                let endComponents = calendar.dateComponents([.hour, .minute], from: endParsed)

                guard let startHour = startComponents.hour, let startMin = startComponents.minute,
                      let endHour = endComponents.hour, let endMin = endComponents.minute else { continue }

                let startTime = calendar.date(bySettingHour: startHour, minute: startMin, second: 0, of: day)!
                let endTime = calendar.date(bySettingHour: endHour, minute: endMin, second: 0, of: day)!

                let block = ScheduleBlock(
                    title: planBlock.title,
                    category: Category(rawValue: planBlock.category),
                    startTime: startTime,
                    endTime: endTime
                )
                dayPlan.blocks.append(block)
                print("✅ Saved block:", planBlock.title, planBlock.startTime, "→", planBlock.endTime, "for", startOfDay)
            }
        }

        try context.save()
        print("✅ Plan saved, total days:", blocksByDate.count)
    }

    func calendarContext(forWeekOf date: Date, context: ModelContext) throws -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysToMonday = (weekday == 1) ? -6 : -(weekday - 2)
        let monday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: daysToMonday, to: date)!)
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!

        let allPlans = try context.fetch(FetchDescriptor<DayPlan>())
        let plans = allPlans.filter { $0.date >= monday && $0.date < nextMonday }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE MMMM d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var lines: [String] = []
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: monday)!
            let startOfDay = calendar.startOfDay(for: day)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let dayPlan = plans.first { p in
                let planDay = calendar.startOfDay(for: p.date)
                return planDay >= startOfDay && planDay < endOfDay
            }

            let dayLabel = dayFormatter.string(from: day)
            if let p = dayPlan, !p.blocks.isEmpty {
                let sorted = p.blocks.sorted { $0.startTime < $1.startTime }
                let items = sorted.map { "\($0.title) \(timeFormatter.string(from: $0.startTime))-\(timeFormatter.string(from: $0.endTime))" }
                lines.append("\(dayLabel): \(items.joined(separator: ", "))")
            } else {
                lines.append("\(dayLabel): No schedule")
            }
        }

        return lines.joined(separator: "\n")
    }
}
