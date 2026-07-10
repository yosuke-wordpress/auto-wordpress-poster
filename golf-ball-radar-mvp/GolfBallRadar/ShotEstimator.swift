import Foundation
import CoreGraphics
import CoreLocation

struct TrackedBallSample {
    let timestamp: TimeInterval
    let normalizedPoint: CGPoint
    let confidence: Double
}

struct ShotEstimator {
    func estimate(origin: CLLocationCoordinate2D,
                  deviceHeading: Double,
                  samples: [TrackedBallSample],
                  selectedClubCarry: Double) -> ShotEstimate {
        let reliable = samples.filter { $0.confidence >= 0.45 }
        let last = reliable.last?.normalizedPoint ?? CGPoint(x: 0.5, y: 0.5)

        // Camera horizontal FOV is approximated for the MVP. Calibration will replace this.
        let horizontalFOV = 65.0
        let horizontalOffset = (Double(last.x) - 0.5) * horizontalFOV
        let bearing = normalize(deviceHeading + horizontalOffset)

        let observationQuality = min(1.0, Double(reliable.count) / 18.0)
        let centerPenalty = abs(Double(last.x) - 0.5) * 18.0
        let uncertainty = max(8.0, 35.0 - observationQuality * 20.0 + centerPenalty)

        return ShotEstimate(
            origin: origin,
            bearingDegrees: bearing,
            estimatedCarryMeters: selectedClubCarry,
            uncertaintyMeters: uncertainty
        )
    }

    private func normalize(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }
}
