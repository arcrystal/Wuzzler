import Foundation

enum SecurityPolicy {
    static let remotePuzzleContentURL = URL(string: "https://arcrystal.github.io/Wuzzler/content/v1/puzzles.json")!
    static let supportURL = URL(string: "https://arcrystal.github.io/Wuzzler/support/")!
    static let privacyURL = URL(string: "https://arcrystal.github.io/Wuzzler/privacy/")!
    static let maximumPuzzleManifestBytes = 2 * 1024 * 1024

    static var usesUITestAuthentication: Bool {
        #if DEBUG
        return hasLaunchArgument("-WuzzlerUITestAuthenticated")
        #else
        return false
        #endif
    }

    static var usesUITestGuest: Bool {
        #if DEBUG
        return hasLaunchArgument("-WuzzlerUITestGuest")
        #else
        return false
        #endif
    }

    static var shouldResetUITestState: Bool {
        #if DEBUG
        return hasLaunchArgument("-WuzzlerUITestResetState")
        #else
        return false
        #endif
    }

    static var shouldSeedDiagoneUITestPiece: Bool {
        #if DEBUG
        return hasLaunchArgument("-WuzzlerUITestPlaceDiagoneP1")
        #else
        return false
        #endif
    }

    static var uiTestPuzzleLoadingMinimumDuration: TimeInterval? {
        #if DEBUG
        guard let rawValue = launchArgumentValue(after: "-WuzzlerUITestPuzzleLoadingMinimumDuration"),
              let duration = TimeInterval(rawValue),
              duration > 0 else {
            return nil
        }
        return duration
        #else
        return nil
        #endif
    }

    static func isApprovedRemoteContentURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        guard components.scheme?.lowercased() == "https" else { return false }
        guard components.host?.lowercased() == "arcrystal.github.io" else { return false }
        guard components.path == "/Wuzzler/content/v1/puzzles.json" else { return false }
        guard components.user == nil, components.password == nil else { return false }
        guard components.query == nil, components.fragment == nil else { return false }
        guard components.port == nil || components.port == 443 else { return false }
        return true
    }

    static func isApprovedRemoteContentResponse(_ response: URLResponse) -> Bool {
        guard let responseURL = response.url else { return false }
        return isApprovedRemoteContentURL(responseURL)
    }

    static func isApprovedJSONMimeType(_ mimeType: String?) -> Bool {
        mimeType?.lowercased() == "application/json"
    }

    static func isResponseSizeAllowed(_ byteCount: Int) -> Bool {
        (0...maximumPuzzleManifestBytes).contains(byteCount)
    }

    static func puzzleContentURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 6
        configuration.waitsForConnectivity = false
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        if #available(iOS 13.0, *) {
            configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        }
        return URLSession(configuration: configuration)
    }

    static func writeProtectedCacheData(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    #if DEBUG
    private static func hasLaunchArgument(_ argument: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    private static func launchArgumentValue(after argument: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let argumentIndex = arguments.firstIndex(of: argument) else { return nil }
        let valueIndex = arguments.index(after: argumentIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
    #endif
}
