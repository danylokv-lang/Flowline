import SwiftUI
import Combine

@MainActor
final class CategoryColorManager: ObservableObject {

    // MARK: - Defaults
    static let defaultWork     = Color(red: 0.55, green: 0.40, blue: 1.00)
    static let defaultStudy    = Color(red: 0.20, green: 0.65, blue: 1.00)
    static let defaultHealth   = Color(red: 0.15, green: 0.85, blue: 0.50)
    static let defaultPersonal = Color(red: 1.00, green: 0.55, blue: 0.20)

    // MARK: - Published colors
    @Published var workColor: Color
    @Published var studyColor: Color
    @Published var healthColor: Color
    @Published var personalColor: Color

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        self.workColor     = Self.load("catColor.work")     ?? Self.defaultWork
        self.studyColor    = Self.load("catColor.study")    ?? Self.defaultStudy
        self.healthColor   = Self.load("catColor.health")   ?? Self.defaultHealth
        self.personalColor = Self.load("catColor.personal") ?? Self.defaultPersonal

        // Persist whenever any color changes
        $workColor    .dropFirst().sink { [weak self] in self?.save($0, key: "catColor.work") }    .store(in: &cancellables)
        $studyColor   .dropFirst().sink { [weak self] in self?.save($0, key: "catColor.study") }   .store(in: &cancellables)
        $healthColor  .dropFirst().sink { [weak self] in self?.save($0, key: "catColor.health") }  .store(in: &cancellables)
        $personalColor.dropFirst().sink { [weak self] in self?.save($0, key: "catColor.personal") }.store(in: &cancellables)
    }

    // MARK: - Lookup
    func color(for category: Category?) -> Color {
        switch category {
        case .work:     return workColor
        case .study:    return studyColor
        case .health:   return healthColor
        case .personal: return personalColor
        case nil:       return Color(white: 0.55)
        }
    }

    // MARK: - Reset
    func resetToDefaults() {
        workColor     = Self.defaultWork
        studyColor    = Self.defaultStudy
        healthColor   = Self.defaultHealth
        personalColor = Self.defaultPersonal
    }

    // MARK: - Persistence
    private func save(_ color: Color, key: String) {
        guard let ns = NSColor(color).usingColorSpace(.deviceRGB) else { return }
        UserDefaults.standard.set(
            [ns.redComponent, ns.greenComponent, ns.blueComponent],
            forKey: key
        )
    }

    private static func load(_ key: String) -> Color? {
        guard let arr = UserDefaults.standard.array(forKey: key) as? [Double],
              arr.count == 3 else { return nil }
        return Color(red: arr[0], green: arr[1], blue: arr[2])
    }
}
