import Foundation

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

