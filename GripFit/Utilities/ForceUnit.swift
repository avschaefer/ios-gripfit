import Foundation

// MARK: - Chart Time Range

enum ChartTimeRange: String, CaseIterable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"
    case allTime = "All"

    var displayName: String { rawValue }

    var days: Int? {
        switch self {
        case .oneWeek: return 7
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .oneYear: return 365
        case .allTime: return nil
        }
    }
}

// MARK: - Readiness Timeframe

enum ReadinessTimeframe: String, CaseIterable {
    case threeDays = "3d"
    case oneWeek = "1w"
    case twoWeeks = "2w"
    case oneMonth = "1mo"

    var displayName: String {
        switch self {
        case .threeDays: return "3 Days"
        case .oneWeek: return "1 Week"
        case .twoWeeks: return "2 Weeks"
        case .oneMonth: return "1 Month"
        }
    }

    var days: Int {
        switch self {
        case .threeDays: return 3
        case .oneWeek: return 7
        case .twoWeeks: return 14
        case .oneMonth: return 30
        }
    }
}

// MARK: - Force Unit

enum ForceUnit: String, Codable, CaseIterable {
    case kilograms
    case pounds

    var abbreviation: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lbs"
        }
    }

    var displayName: String {
        switch self {
        case .kilograms: return "Kilograms"
        case .pounds: return "Pounds"
        }
    }

    func convert(_ kg: Double) -> Double {
        switch self {
        case .kilograms: return kg
        case .pounds: return kg * 2.20462
        }
    }

    func format(_ kg: Double, decimals: Int = 1) -> String {
        let converted = convert(kg)
        return String(format: "%.\(decimals)f %@", converted, abbreviation)
    }
}

