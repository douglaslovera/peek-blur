import AppKit

/// A blurred, click-through window over every screen.
@MainActor
final class BlurOverlay {
    private var windows: [NSWindow] = []
    private(set) var isShown = false

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuildWindows() }
        }
        rebuildWindows()
    }

    func show() {
        guard !isShown else { return }
        isShown = true
        for window in windows {
            window.alphaValue = 0
            window.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            windows.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.isShown else { return }
                self.windows.forEach { $0.orderOut(nil) }
            }
        })
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map(makeWindow)
        if isShown { windows.forEach { $0.orderFrontRegardless() } }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.setFrame(screen.frame, display: false)
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.alphaValue = 0

        // Blurs whatever is behind the window. No screen recording needed.
        let blur = NSVisualEffectView()
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active

        let label = NSTextField(labelWithString: "👀  Look back to unblur")
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: blur.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: blur.centerYAnchor),
        ])

        window.contentView = blur
        return window
    }
}
