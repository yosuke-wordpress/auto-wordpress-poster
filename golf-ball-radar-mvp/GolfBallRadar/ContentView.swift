import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var session: ShotSessionStore

    @State private var selectedCarry = 180.0
    @State private var manualDirectionCorrection = 0.0
    @State private var showingRadar = false

    var body: some View {
        NavigationStack {
            Form {
                Section("自分のボール") {
                    TextField("名称", text: $session.ballIdentity.name)
                    TextField("識別マーク", text: $session.ballIdentity.markCode)
                    Text("同伴者と重複しない2色マークや文字列を登録します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("ショット設定") {
                    HStack {
                        Text("想定キャリー")
                        Spacer()
                        Text("\(selectedCarry, specifier: "%.0f") m")
                    }
                    Slider(value: $selectedCarry, in: 60...260, step: 5)

                    HStack {
                        Text("左右補正")
                        Spacer()
                        Text("\(manualDirectionCorrection, specifier: "%+.0f")°")
                    }
                    Slider(value: $manualDirectionCorrection, in: -35...35, step: 1)
                }

                Section("撮影") {
                    CameraTrackerView { samples in
                        createEstimate(samples: samples)
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button("シミュレーションで着地点を作成") {
                        let samples = (0..<15).map { index in
                            TrackedBallSample(
                                timestamp: Double(index) / 120,
                                normalizedPoint: CGPoint(x: 0.50 + Double(index) * 0.006, y: 0.68 - Double(index) * 0.022),
                                confidence: 0.8
                            )
                        }
                        createEstimate(samples: samples)
                    }
                }

                if let estimate = session.currentEstimate {
                    Section("最新推定") {
                        LabeledContent("方位", value: "\(estimate.bearingDegrees, specifier: "%.0f")°")
                        LabeledContent("距離", value: "\(estimate.estimatedCarryMeters, specifier: "%.0f") m")
                        LabeledContent("探索半径", value: "約 \(estimate.uncertaintyMeters, specifier: "%.0f") m")
                        Button("レーダーで探す") { showingRadar = true }
                    }
                }
            }
            .navigationTitle("Golf Ball Radar")
            .onAppear { locationService.requestPermissionAndStart() }
            .sheet(isPresented: $showingRadar) {
                if let estimate = session.currentEstimate {
                    NavigationStack {
                        RadarView(
                            estimate: estimate,
                            userLocation: locationService.location,
                            headingDegrees: locationService.headingDegrees
                        )
                        .navigationTitle("ボール探索")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("閉じる") { showingRadar = false }
                            }
                        }
                    }
                }
            }
        }
    }

    private func createEstimate(samples: [TrackedBallSample]) {
        guard let coordinate = locationService.location?.coordinate else { return }
        let estimator = ShotEstimator()
        let result = estimator.estimate(
            origin: coordinate,
            deviceHeading: locationService.headingDegrees + manualDirectionCorrection,
            samples: samples,
            selectedClubCarry: selectedCarry
        )
        session.save(result)
        showingRadar = true
    }
}
