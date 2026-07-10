import Foundation
import CoreLocation

struct BallIdentity: Codable, Hashable {
    var name: String
    var markCode: String
}

struct ShotEstimate: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let originLatitude: Double
    let originLongitude: Double
    let bearingDegrees: Double
    let estimatedCarryMeters: Double
    let uncertaintyMeters: Double

    init(origin: CLLocationCoordinate2D,
         bearingDegrees: Double,
         estimatedCarryMeters: Double,
         uncertaintyMeters: Double) {
        self.id = UUID()
        self.createdAt = Date()
        self.originLatitude = origin.latitude
        self.originLongitude = origin.longitude
        self.bearingDegrees = bearingDegrees
        self.estimatedCarryMeters = estimatedCarryMeters
        self.uncertaintyMeters = uncertaintyMeters
    }

    var origin: CLLocationCoordinate2D {
        .init(latitude: originLatitude, longitude: originLongitude)
    }

    var target: CLLocationCoordinate2D {
        origin.destination(distance: estimatedCarryMeters, bearing: bearingDegrees)
    }
}

@MainActor
final class ShotSessionStore: ObservableObject {
    @Published var currentEstimate: ShotEstimate?
    @Published var history: [ShotEstimate] = []
    @Published var ballIdentity = BallIdentity(name: "My Ball", markCode: "HS-01")

    func save(_ estimate: ShotEstimate) {
        currentEstimate = estimate
        history.insert(estimate, at: 0)
    }
}

extension CLLocationCoordinate2D {
    func destination(distance: Double, bearing: Double) -> CLLocationCoordinate2D {
        let radius = 6_371_000.0
        let angularDistance = distance / radius
        let bearingRadians = bearing * .pi / 180
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(angularDistance) +
                        cos(lat1) * sin(angularDistance) * cos(bearingRadians))
        let lon2 = lon1 + atan2(sin(bearingRadians) * sin(angularDistance) * cos(lat1),
                                cos(angularDistance) - sin(lat1) * sin(lat2))
        return .init(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}
