import SwiftUI

@MainActor
final class DesignSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var accentName: String {
        didSet { defaults.set(accentName, forKey: Keys.accentName) }
    }

    @Published var cardCornerRadius: Double {
        didSet { defaults.set(cardCornerRadius, forKey: Keys.cardCornerRadius) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accentName = defaults.string(forKey: Keys.accentName) ?? "green"
        let storedRadius = defaults.double(forKey: Keys.cardCornerRadius)
        cardCornerRadius = storedRadius == 0 ? 18 : storedRadius
    }

    func reset() {
        accentName = "green"
        cardCornerRadius = 18
        defaults.removeObject(forKey: Keys.accentName)
        defaults.removeObject(forKey: Keys.cardCornerRadius)
    }

    var accentColor: Color {
        switch accentName {
        case "blue":
            return AppStyle.secondary
        case "green":
            return AppStyle.accent
        case "orange":
            return AppStyle.sun
        default:
            return AppStyle.ink
        }
    }

    private enum Keys {
        static let accentName = "design.accentName"
        static let cardCornerRadius = "design.cardCornerRadius"
    }
}
