import Foundation

enum AppConstants {
    static let appName = "GripTrack"
    static let minimumPasswordLength = 8

    enum Tabs {
        static let dashboard = "Dashboard"
        static let device = "Device"
        static let settings = "Settings"
    }

    enum Icons {
        static let dashboard = "house.fill"
        static let device = "sensor.fill"
        static let settings = "gearshape.fill"
        static let recording = "waveform"
        static let leftHand = "hand.point.left.fill"
        static let rightHand = "hand.point.right.fill"
        static let clock = "clock.fill"
        static let flame = "flame.fill"
        static let chartBar = "chart.bar.fill"
        static let person = "person.fill"
        static let signOut = "rectangle.portrait.and.arrow.right"
        static let bluetooth = "antenna.radiowaves.left.and.right"
        static let connected = "checkmark.circle.fill"
        static let disconnected = "xmark.circle.fill"
        static let scanning = "magnifyingglass"
        static let trash = "trash"
    }

    enum UserDefaultsKeys {
        static let preferredUnit = "preferredUnit"
        static let dominantHand = "dominantHand"
    }

    enum ErrorMessages {
        static let genericError = "Something went wrong. Please try again."
        static let networkError = "Unable to connect. Please check your internet connection."
        static let authError = "Authentication failed. Please try again."
        static let passwordMismatch = "Passwords do not match."
        static let passwordTooShort = "Password must be at least \(AppConstants.minimumPasswordLength) characters."
        static let invalidEmail = "Please enter a valid email address."
        static let emptyFields = "Please fill in all fields."
    }
}

