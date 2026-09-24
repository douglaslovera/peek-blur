import Foundation

/// Turns raw face readings into "blur" / "unblur" decisions.
@MainActor
final class AttentionMonitor: ObservableObject {
    @Published var isEnabled = false {
        didSet { isEnabled ? camera.start() : stopAndUnblur() }
    }
    /// Seconds you must look away before the screen blurs.
    @Published var blurDelay: Double = 1.5
    /// How far (radians) your head can turn from the calibrated pose and still count as looking.
    @Published var tolerance: Double = 0.35

    @Published private(set) var lastReading = FaceReading(faceFound: false)
    @Published private(set) var isLooking = true
    @Published private(set) var isBlurred = false

    private var baselineYaw = 0.0
    private var baselinePitch = 0.0
    private var lookingAwaySince: Date?

    private let camera = CameraFeed()
    private let overlay = BlurOverlay()

    init() {
        camera.onReading = { [weak self] reading in
            Task { @MainActor in self?.handle(reading) }
        }
    }

    /// Records your current head pose as "looking at the screen".
    func calibrate() {
        guard lastReading.faceFound else { return }
        baselineYaw = lastReading.yaw
        baselinePitch = lastReading.pitch
    }

    /// Flash the blur for a moment so you can see what it looks like.
    func previewBlur() {
        overlay.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, !self.isBlurred else { return }
            self.overlay.hide()
        }
    }

    var yawOffset: Double { lastReading.yaw - baselineYaw }
    var pitchOffset: Double { lastReading.pitch - baselinePitch }

    private func handle(_ reading: FaceReading) {
        guard isEnabled else { return }
        lastReading = reading

        isLooking = reading.faceFound
            && abs(yawOffset) < tolerance
            && abs(pitchOffset) < tolerance

        if isLooking {
            lookingAwaySince = nil
            setBlurred(false)  // unblur right away
        } else {
            let since = lookingAwaySince ?? Date()
            lookingAwaySince = since
            if Date().timeIntervalSince(since) >= blurDelay {
                setBlurred(true)
            }
        }
    }

    private func setBlurred(_ blurred: Bool) {
        guard blurred != isBlurred else { return }
        isBlurred = blurred
        blurred ? overlay.show() : overlay.hide()
    }

    private func stopAndUnblur() {
        camera.stop()
        lookingAwaySince = nil
        isLooking = true
        setBlurred(false)
    }
}
