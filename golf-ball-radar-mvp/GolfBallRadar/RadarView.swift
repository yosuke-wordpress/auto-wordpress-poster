import SwiftUI
import CoreLocation

struct RadarView: View {
    let estimate: ShotEstimate
    let userLocation: CLLocation?
    let headingDegrees: Double

    private var targetLocation: CLLocation {
        CLLocation(latitude: estimate.target.latitude, longitude: estimate.target.longitude)
    }

    private var distance: Double {
        guard let userLocation else { return estimate.estimatedCarryMeters }
        return userLocation.distance(from: targetLocation)
    }

    private var relativeBearing: Double {
        guard let userLocation else { return estimate.bearingDegrees - headingDegrees }
        let absolute = bearing(from: userLocation.coordinate, to: estimate.target)
        return absolute - headingDegrees
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach([0.28, 0.55, 0.82], id: \.self) { scale in
                    Circle()
                        .stroke(.secondary.opacity(0.35), lineWidth: 1)
                        .scaleEffect(scale)
                }
                Circle()
                    .fill(.green.opacity(0.12))
                Path { path in
                    path.move(to: CGPoint(x: 150, y: 150))
                    path.addLine(to: CGPoint(x: 150, y: 20))
                }
                .stroke(.green.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [5, 6]))

                Image(systemName: "circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.yellow)
                    .offset(y: -105)
                    .rotationEffect(.degrees(relativeBearing))
                    .shadow(radius: 4)

                Circle()
                    .fill(.blue)
                    .frame(width: 14, height: 14)
            }
            .frame(width: 300, height: 300)
            .rotationEffect(.degrees(-headingDegrees))

            Text("推定地点まで \(distance, specifier: "%.0f") m")
                .font(.title2.bold())
            Text("探索半径 約 \(estimate.uncertaintyMeters, specifier: "%.0f") m")
                .foregroundStyle(.secondary)
            Text("黄色の点がボール推定地点です。スマートフォンの向きを変え、上方向に点を合わせて進みます。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let degrees = atan2(y, x) * 180 / .pi
        return degrees >= 0 ? degrees : degrees + 360
    }
}
