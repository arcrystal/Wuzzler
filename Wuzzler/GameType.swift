import SwiftUI

enum GameType: String, Identifiable, CaseIterable {
    case diagone
    case rhymeAGrams
    case tumblePuns

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diagone: return "Diagone"
        case .rhymeAGrams: return "RhymeAGram"
        case .tumblePuns: return "TumblePun"
        }
    }

    var iconSystemName: String {
        switch self {
        case .diagone: return "square.grid.3x3.fill"
        case .rhymeAGrams: return "triangle.fill"
        case .tumblePuns: return "circle.grid.3x3.fill"
        }
    }

    var description: String {
        switch self {
        case .diagone: return "Drag and drop diagonals to spell six horizontal words"
        case .rhymeAGrams: return "Find four rhyming words. Use each letter once"
        case .tumblePuns: return "Unscramble words and solve the punny definition"
        }
    }

    var accentColor: Color {
        switch self {
        case .diagone: return .diagoneAccent
        case .rhymeAGrams: return .rhymeAGramsAccent
        case .tumblePuns: return .tumblePunsAccent
        }
    }
}
