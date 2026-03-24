import Foundation
import SwiftData
import WidgetKit

/// Writes today's schedule to the shared App Group so the widget can display it.
/// Call `refresh(context:)` any time blocks are created, updated, or deleted.
struct WidgetDataWriter {

    static let shared = WidgetDataWriter()
    private init() {}

    func refresh(context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let descriptor = FetchDescriptor<ScheduleBlock>(
            predicate: #Predicate { $0.startTime >= today && $0.startTime < tomorrow },
            sortBy: [SortDescriptor(\.startTime)]
        )

        guard let blocks = try? context.fetch(descriptor) else { return }

        let widgetBlocks = blocks.map { block in
            WidgetBlock(
                id: block.persistentModelID.hashValue.description,
                title: block.title,
                startTime: block.startTime,
                endTime: block.endTime,
                category: block.category?.rawValue ?? "personal"
            )
        }

        let data = WidgetDayData(blocks: widgetBlocks, updatedAt: Date())
        WidgetDayData.save(data)

        // Tell WidgetKit to reload all timelines immediately
        WidgetCenter.shared.reloadAllTimelines()
    }
}
