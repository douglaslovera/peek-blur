import AVFoundation
import Vision

/// What Vision saw in a single frame.
struct FaceReading {
    var faceFound: Bool
    var yaw: Double = 0    // radians, + is turning to your left
    var pitch: Double = 0  // radians, + is looking down
}

/// Pulls frames from the webcam, runs face detection on a few per second,
/// and reports a `FaceReading` for each processed frame.
final class CameraFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onReading: ((FaceReading) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "PeekBlur.camera")
    private let framesPerSecond: Double = 6
    private var lastProcessed = Date.distantPast
    private var configured = false

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.queue.async {
                if !self.configured { self.configure() }
                if !self.session.isRunning { self.session.startRunning() }
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480  // plenty for face detection

        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            print("PeekBlur: no usable camera")
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessed) >= 1 / framesPerSecond,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        lastProcessed = now

        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3  // gives yaw + pitch
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up).perform([request])

        // If several faces are visible, assume the biggest one is you.
        let face = request.results?.max { a, b in
            a.boundingBox.width * a.boundingBox.height < b.boundingBox.width * b.boundingBox.height
        }

        let reading: FaceReading
        if let face {
            reading = FaceReading(
                faceFound: true,
                yaw: face.yaw?.doubleValue ?? 0,
                pitch: face.pitch?.doubleValue ?? 0
            )
        } else {
            reading = FaceReading(faceFound: false)
        }
        onReading?(reading)
    }
}
