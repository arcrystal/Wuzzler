import SwiftUI

/// Application entry point. Launches the game UI within a single window. The
/// `@main` attribute ensures this struct is used as the main entry when
/// building an iOS app. On launch the app displays the home screen with
/// multiple game options.
@main
struct WuzzlerApp: App {
    @AppStorage("appearance_mode") private var appearanceMode: AppearanceMode = .system

    init() {
        if SecurityPolicy.shouldResetUITestState {
            let prefixes = ["diagone", "rhymeagrams", "tumblepuns"]
            for key in UserDefaults.standard.dictionaryRepresentation().keys {
                if prefixes.contains(where: key.hasPrefix) || key == "last_daily_sweep_celebrated" {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}
