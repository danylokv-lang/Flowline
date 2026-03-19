import SwiftUI
import Combine

@MainActor
final class CategoryColorManager: ObservableObject {

    // MARK: - Defaults (matches website --work / --study / --health / --personal tokens)
    static let defaultWork     = Color(hex: "#7c5cf8")   // purple  --work
    static let defaultStudy    = Color(hex: "#3b9eff")   // blue    --study
    static let defaultHealth   = Color(hex: "#2ecc71")   // green   --health
    static let defaultPersonal = Color(hex: "#ff7b45")   // orange  --personal

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
