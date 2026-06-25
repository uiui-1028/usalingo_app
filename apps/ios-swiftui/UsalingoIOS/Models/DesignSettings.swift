import SwiftUI

@MainActor
final class DesignSettings: ObservableObject {
    @Published var accentName: String {
        didSet { UserDefaults.standard.set(accentName, forKey: Keys.accentName) }
    }

    @Published var cardCornerRadius: Double {
        didSet { UserDefaults.standard.set(cardCornerRadius, forKey: Keys.cardCornerRadius) }
    }

    @Published var isTTSEnabled: Bool {
        didSet { UserDefaults.standard.set(isTTSEnabled, forKey: Keys.isTTSEnabled) }
    }

    init() {
        let defaults = UserDefaults.standard
        accentName = defaults.string(forKey: Keys.accentName) ?? "green"
        let storedRadius = defaults.double(forKey: Keys.cardCornerRadius)
        cardCornerRadius = storedRadius == 0 ? 18 : storedRadius
        isTTSEnabled = defaults.object(forKey: Keys.isTTSEnabled) as? Bool ?? true
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
            return Color(red: 1.0, green: 0.36, blue: 0.59)
        }
    }

    private enum Keys {
        static let accentName = "design.accentName"
        static let cardCornerRadius = "design.cardCornerRadius"
        static let isTTSEnabled = "design.isTTSEnabled"
    }
}
