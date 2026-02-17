import SwiftUI
import UIKit

// MARK: - Haptics Utility

extension UserDefaults {
    var hapticsEnabled: Bool {
        object(forKey: "haptics_enabled") as? Bool ?? true
    }
}

enum Haptics {
    // Reusable generators — avoids cold-start stall from creating a new one each call.
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)

    /// Warm up the Taptic Engine so the next haptic fires without lag.
    /// Call this just before a win animation or any time-sensitive sequence.
    static func prepare() {
        guard UserDefaults.standard.hapticsEnabled else { return }
        notificationGenerator.prepare()
        softImpactGenerator.prepare()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard UserDefaults.standard.hapticsEnabled else { return }
        notificationGenerator.notificationOccurred(type)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        guard UserDefaults.standard.hapticsEnabled else { return }
        if style == .soft {
            softImpactGenerator.impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}

// MARK: - Game Accent Environment Key

private struct GameAccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .diagoneAccent
}

extension EnvironmentValues {
    var gameAccent: Color {
        get { self[GameAccentColorKey.self] }
        set { self[GameAccentColorKey.self] = newValue }
    }
}

/// Defines colour tokens used throughout the application. Centralising the palette
/// makes it easy to adjust appearance for light and dark modes or customise
/// themes via a configuration file in the future. Colours are exposed as
/// static computed properties on `Color` for convenience.
extension Color {
    /// Background colour for individual board cells. A subtle off‑white in light
    /// mode and a dark grey in dark mode to retain appropriate contrast.
    static var boardCell: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0) : UIColor(red: 0.97, green: 0.97, blue: 0.94, alpha: 1.0)
        })
    }
    /// Colour for the grid lines separating cells. Uses a soft grey in light
    /// mode and a lighter grey in dark mode.
    static var gridLine: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(red: 0.32, green: 0.32, blue: 0.35, alpha: 1.0) : UIColor(red: 0.84, green: 0.84, blue: 0.86, alpha: 1.0)
        })
    }
    /// Colour for the main diagonal cells — kept as the Diagone blue for
    /// backward compatibility. New code should prefer `gameAccent`.
    static var mainDiagonal: Color { diagoneAccent }

    // MARK: - Per-Game Accent Colors

    /// Diagone: a rich but calm blue
    static var diagoneAccent: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.35, green: 0.65, blue: 0.88, alpha: 1.0)
                : UIColor(red: 0.15, green: 0.40, blue: 0.70, alpha: 1.0)
        })
    }
    /// RhymeAGrams: a fresh, leafy green
    static var rhymeAGramsAccent: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.30, green: 0.75, blue: 0.50, alpha: 1.0)
                : UIColor(red: 0.16, green: 0.55, blue: 0.35, alpha: 1.0)
        })
    }
    /// TumblePuns: a warm, playful red-coral
    static var tumblePunsAccent: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.90, green: 0.42, blue: 0.40, alpha: 1.0)
                : UIColor(red: 0.78, green: 0.25, blue: 0.22, alpha: 1.0)
        })
    }

    /// Colour used to tint rows during the win animation. A warm yellow
    /// (#F9C23C) reminiscent of the NYT accent. Slightly desaturated in dark
    /// mode.
    static var accent: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(red: 0.88, green: 0.70, blue: 0.26, alpha: 1.0) : UIColor(red: 0.97, green: 0.76, blue: 0.24, alpha: 1.0)
        })
    }
    /// Colour used to highlight valid drop targets while dragging. Uses the
    /// accent colour at reduced opacity.
    static var hoverHighlight: Color {
        accent.opacity(0.4)
    }
    /// Colour for letters displayed on the board. Black in light mode and
    /// off‑white in dark mode.
    static var letter: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) : UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        })
    }
}
