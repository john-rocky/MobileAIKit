import Foundation
import AIKit

/// A configurable selection of tool packs drawn from `AIKitIntegration`.
public struct IntegrationToolPackOptions: Sendable {
    public var includeCalendar: Bool
    public var includeContacts: Bool
    public var includeHealth: Bool
    public var includeMaps: Bool
    public var includeWeather: Bool
    public var includeLocation: Bool
    public var includeWeb: Bool
    public var includePDF: Bool
    public var includePhotos: Bool
    public var includeMotion: Bool
    public var includeHome: Bool
    public var includeMusic: Bool
    public var includeNotifications: Bool
    public var includeFiles: Bool
    public var filesRoot: URL?
    public var webSearchProvider: (any WebSearchProvider)?

    public init(
        includeCalendar: Bool = true,
        includeContacts: Bool = true,
        includeHealth: Bool = true,
        includeMaps: Bool = true,
        includeWeather: Bool = true,
        includeLocation: Bool = true,
        includeWeb: Bool = true,
        includePDF: Bool = true,
        includePhotos: Bool = true,
        includeMotion: Bool = true,
        includeHome: Bool = true,
        includeMusic: Bool = true,
        includeNotifications: Bool = true,
        includeFiles: Bool = true,
        filesRoot: URL? = nil,
        webSearchProvider: (any WebSearchProvider)? = nil
    ) {
        self.includeCalendar = includeCalendar
        self.includeContacts = includeContacts
        self.includeHealth = includeHealth
        self.includeMaps = includeMaps
        self.includeWeather = includeWeather
        self.includeLocation = includeLocation
        self.includeWeb = includeWeb
        self.includePDF = includePDF
        self.includePhotos = includePhotos
        self.includeMotion = includeMotion
        self.includeHome = includeHome
        self.includeMusic = includeMusic
        self.includeNotifications = includeNotifications
        self.includeFiles = includeFiles
        self.filesRoot = filesRoot
        self.webSearchProvider = webSearchProvider
    }

    public static let `default` = IntegrationToolPackOptions()
}

@MainActor
public extension AIAgent {
    /// Registers every integration tool whose underlying framework is available on
    /// this platform. Each tool is guarded by `canImport`, so frameworks missing
    /// at link time (e.g. WeatherKit on simulator without entitlement) are simply
    /// skipped.
    ///
    /// Tools that read user data are registered with `sideEffectFree: true` so the
    /// agent's auto-approve-read-only option can fire them without prompting; tools
    /// that create events, toggle accessories, or send notifications always route
    /// through ``AgentHost/confirm(title:message:isDestructive:)``.
    func registerIntegrationTools(options: IntegrationToolPackOptions = .default) async {
        var tools: [any Tool] = []

        #if canImport(EventKit)
        if options.includeCalendar {
            let bridge = EventKitBridge()
            tools.append(bridge.listEventsTool())
            tools.append(bridge.createEventTool())
        }
        #endif

        #if canImport(Contacts)
        if options.includeContacts {
            let bridge = ContactsBridge()
            tools.append(bridge.searchTool())
        }
        #endif

        #if canImport(HealthKit)
        if options.includeHealth, HealthKitBridge.isAvailable {
            let bridge = HealthKitBridge()
            tools.append(bridge.recentStepCountTool())
        }
        #endif

        #if canImport(MapKit)
        if options.includeMaps {
            tools.append(MapKitBridge.searchPlacesTool())
            tools.append(MapKitBridge.directionsTool())
        }
        #endif

        #if canImport(WeatherKit)
        if options.includeWeather {
            let bridge = WeatherKitBridge()
            tools.append(bridge.currentWeatherTool())
            tools.append(bridge.dailyForecastTool())
        }
        #endif

        #if canImport(CoreLocation)
        if options.includeLocation {
            let bridge = LocationBridge()
            tools.append(bridge.currentLocationTool())
        }
        #endif

        if options.includeWeb {
            let provider: any WebSearchProvider = options.webSearchProvider ?? DuckDuckGoSearchProvider()
            tools.append(WebSearch.tool(provider: provider))
            tools.append(WebPageReader.readerTool())
            tools.append(WebTools.httpGetTool())
        }

        #if canImport(PDFKit)
        if options.includePDF {
            tools.append(PDFExtractor.readerTool())
        }
        #endif

        #if canImport(Photos)
        if options.includePhotos {
            let bridge = PhotosBridge()
            tools.append(bridge.recentPhotosTool())
        }
        #endif

        #if canImport(CoreMotion)
        if options.includeMotion {
            let bridge = MotionBridge()
            tools.append(bridge.stepCountTool())
        }
        #endif

        #if canImport(HomeKit) && os(iOS)
        if options.includeHome {
            let bridge = HomeKitBridge()
            tools.append(bridge.listAccessoriesTool())
            tools.append(bridge.setPowerStateTool())
        }
        #endif

        #if canImport(MusicKit)
        if options.includeMusic {
            let bridge = MusicKitBridge()
            tools.append(bridge.searchSongsTool())
            tools.append(bridge.playSongTool())
        }
        #endif

        #if canImport(UserNotifications)
        if options.includeNotifications {
            tools.append(NotificationBridge.scheduleTool())
        }
        #endif

        if options.includeFiles {
            tools.append(FileTools.readTextFileTool(root: options.filesRoot))
            tools.append(FileTools.listDirectoryTool(root: options.filesRoot))
        }

        await addTools(tools)
    }
}
