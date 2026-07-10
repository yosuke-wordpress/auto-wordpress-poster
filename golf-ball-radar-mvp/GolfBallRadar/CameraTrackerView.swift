import SwiftUI
import AVFoundation
import Vision

struct CameraTrackerView: UIViewControllerRepresentable {
    let onFinished: ([TrackedBallSample]) -> Void

    func makeUIViewController(context: Context) -> CameraTrackerViewController {
        let controller = CameraTrackerViewController()
        controller.onFinished = onFinished
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraTrackerViewController, context: Context) {}
}

final class CameraTrackerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFinished: (([TrackedBallSample]) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "golf.ball.video.queue")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var trackingRequest: VNTrackObjectRequest?
    private var sequenceHandler = VNSequenceRequestHandler()
    private var samples: [TrackedBallSample] = []
    private var isRecordingShot = false
    private var firstTimestamp: CMTime?

    private let statusLabel = UILabel()
    private let recordButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCamera()
        configureOverlay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureCamera() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            showStatus("カメラを開始できません")
            return
        }
        session.addInput(input)

        if let format = camera.formats
            .filter({ $0.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 120 }) })
            .max(by: { CMVideoFormatDescriptionGetDimensions($0.formatDescription).width < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width }) {
            do {
                try camera.lockForConfiguration()
                camera.activeFormat = format
                let range = format.videoSupportedFrameRateRanges.first { $0.maxFrameRate >= 120 }
                let fps = min(120.0, range?.maxFrameRate ?? 60.0)
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                camera.unlockForConfiguration()
            } catch {
                showStatus("高速度撮影を設定できません")
            }
        }

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.connection(with: .video)?.videoRotationAngle = 90

        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        videoQueue.async { [weak self] in self?.session.startRunning() }
    }

    private func configureOverlay() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "iPhoneをティー後方に固定し、ボールを画面中央下に合わせます"
        statusLabel.textColor = .white
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true

        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.setTitle("追跡開始", for: .normal)
        recordButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        recordButton.backgroundColor = .systemYellow
        recordButton.tintColor = .black
        recordButton.layer.cornerRadius = 24
        recordButton.addTarget(self, action: #selector(toggleTracking), for: .touchUpInside)

        let guide = UIView()
        guide.translatesAutoresizingMaskIntoConstraints = false
        guide.layer.borderColor = UIColor.systemYellow.cgColor
        guide.layer.borderWidth = 2
        guide.layer.cornerRadius = 14
        guide.isUserInteractionEnabled = false

        view.addSubview(guide)
        view.addSubview(statusLabel)
        view.addSubview(recordButton)

        NSLayoutConstraint.activate([
            guide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 65),
            guide.widthAnchor.constraint(equalToConstant: 58),
            guide.heightAnchor.constraint(equalToConstant: 58),

            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 132),
            recordButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    @objc private func toggleTracking() {
        if isRecordingShot {
            finishTracking()
        } else {
            samples.removeAll()
            firstTimestamp = nil
            sequenceHandler = VNSequenceRequestHandler()

            // Vision coordinates: origin is bottom-left. The guide is centered slightly below image center.
            let initialBox = CGRect(x: 0.44, y: 0.27, width: 0.12, height: 0.12)
            trackingRequest = VNTrackObjectRequest(detectedObjectObservation: VNDetectedObjectObservation(boundingBox: initialBox))
            trackingRequest?.trackingLevel = .accurate
            isRecordingShot = true
            DispatchQueue.main.async {
                self.recordButton.setTitle("追跡終了", for: .normal)
                self.recordButton.backgroundColor = .systemRed
                self.recordButton.tintColor = .white
                self.statusLabel.text = "打ってください。球が見えなくなったら追跡終了を押します"
            }
        }
    }

    private func finishTracking() {
        isRecordingShot = false
        trackingRequest = nil
        let result = samples
        DispatchQueue.main.async {
            self.recordButton.setTitle("追跡開始", for: .normal)
            self.recordButton.backgroundColor = .systemYellow
            self.recordButton.tintColor = .black
            self.statusLabel.text = result.isEmpty ? "ボールを追跡できませんでした。方向を手動補正してください" : "\(result.count)フレームを追跡しました"
            self.onFinished?(result)
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard isRecordingShot,
              let request = trackingRequest,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        if firstTimestamp == nil { firstTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) }

        do {
            try sequenceHandler.perform([request], on: pixelBuffer)
            guard let observation = request.results?.first as? VNDetectedObjectObservation else { return }

            let box = observation.boundingBox
            let center = CGPoint(x: box.midX, y: 1 - box.midY)
            let start = firstTimestamp ?? .zero
            let elapsed = CMTimeGetSeconds(CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(sampleBuffer), start))
            samples.append(.init(timestamp: elapsed, normalizedPoint: center, confidence: Double(observation.confidence)))

            if observation.confidence < 0.25 || request.isLastFrame {
                finishTracking()
            } else {
                trackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                trackingRequest?.trackingLevel = .accurate
            }
        } catch {
            finishTracking()
        }
    }

    private func showStatus(_ text: String) {
        DispatchQueue.main.async { self.statusLabel.text = text }
    }
}
