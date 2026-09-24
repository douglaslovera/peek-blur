import SwiftUI

@main
struct PeekBlurApp: App {
    @StateObject private var monitor = AttentionMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuView(monitor: monitor)
        } label: {
            Image(systemName: menuIcon)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuIcon: String {
        if !monitor.isEnabled { return "eye.slash" }
        return monitor.isBlurred ? "eye.trianglebadge.exclamationmark" : "eye"
    }
}

struct MenuView: View {
    @ObservedObject var monitor: AttentionMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Watch me", isOn: $monitor.isEnabled)
                .toggleStyle(.switch)
                .font(.headline)

            if monitor.isEnabled {
                status
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Blur after \(monitor.blurDelay, specifier: "%.1f")s")
                Slider(value: $monitor.blurDelay, in: 0.3...5)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Head turn tolerance \(monitor.tolerance, specifier: "%.2f") rad")
                Slider(value: $monitor.tolerance, in: 0.1...0.8)
            }

            HStack {
                Button("Calibrate") { monitor.calibrate() }
                    .disabled(!monitor.isEnabled || !monitor.lastReading.faceFound)
                    .help("Look at the screen normally, then click")
                Button("Preview blur") { monitor.previewBlur() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 280)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                monitor.isLooking ? "Looking at screen" : (monitor.lastReading.faceFound ? "Looking away" : "No face"),
                systemImage: monitor.isLooking ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundStyle(monitor.isLooking ? .green : .orange)

            if monitor.lastReading.faceFound {
                Text("yaw \(monitor.yawOffset, specifier: "%+.2f")  ·  pitch \(monitor.pitchOffset, specifier: "%+.2f")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
