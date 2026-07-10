import SwiftUI

@main
struct GolfBallRadarApp: App {
    @StateObject private var locationService = LocationService()
    @StateObject private var session = ShotSessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationService)
                .environmentObject(session)
        }
    }
}
