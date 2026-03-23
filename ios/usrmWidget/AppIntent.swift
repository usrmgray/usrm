//
//  AppIntent.swift
//  usrmWidget
//
//  Configuration Intent: Dashboard 선택 + Theme 선택
//

import WidgetKit
import AppIntents

enum WidgetTheme: String, AppEnum {
    case black = "black"
    case white = "white"
    case daylight = "daylight"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Theme"
    }
    
    static var caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] {
        [
            .black: "Black",
            .white: "White",
            .daylight: "Daylight (AM/PM)"
        ]
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "usrm Widget" }
    static var description: IntentDescription { "Display your daily records at a glance." }

    @Parameter(title: "Dashboard", default: "mood")
    var dashboardName: String
    
    @Parameter(title: "Theme", default: .black)
    var theme: WidgetTheme
}

// MARK: - Interactive Toggles
struct ToggleTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Digital Time"
    static var description = IntentDescription("Shows or hides the digital time overlay.")
    
    // Use the same app group as defined in the Provider
    private let appGroupId = "group.com.antigravity.usrm"
    
    func perform() async throws -> some IntentResult {
        if let userDefaults = UserDefaults(suiteName: appGroupId) {
            let current = userDefaults.bool(forKey: "showDigitalTime")
            userDefaults.set(!current, forKey: "showDigitalTime")
        }
        return .result()
    }
}
