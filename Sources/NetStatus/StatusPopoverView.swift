import ServiceManagement
import SwiftUI

struct StatusPopoverView: View {
    @ObservedObject var monitor: NetworkMonitor
    let updater: Updater

    @AppStorage("notifyEnabled") private var notifyEnabled = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            historySection
            Divider()

            Button("Check now") { monitor.checkNow() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Notify on drop and reconnect", isOn: $notifyEnabled)
                Toggle("Open at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
            }
            .toggleStyle(.switch)
            .font(.system(size: 13))

            Divider()

            HStack {
                Text("Version \(Updater.currentVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Check for Updates…") { updater.checkNow() }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.link)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 280)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(nsColor: StatusIcon.color(for: monitor.status)))
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LAST 5 MINUTES")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Sparkline(samples: monitor.history, color: StatusIcon.color(for: monitor.status))
                .frame(height: 32)
            Text(lastCheckText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        switch monitor.status {
        case .online: return "Internet OK"
        case .slow: return "Unstable connection"
        case .offline: return "No internet"
        case .checking: return "Checking…"
        }
    }

    private var subtitle: String {
        switch monitor.status {
        case .online, .slow:
            guard let ms = monitor.latencyMs else { return "Checking connection" }
            return "Latency: \(Int(ms))ms"
        case .offline:
            return "No response from the test server"
        case .checking:
            return "Checking connection now"
        }
    }

    private var lastCheckText: String {
        guard let date = monitor.lastCheck else { return "Last checked: —" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        return "Last checked: " + formatter.localizedString(for: date, relativeTo: Date())
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// A minimal line chart of recent latency samples; an offline sample is plotted at the top of the range.
private struct Sparkline: View {
    let samples: [Sample]
    let color: NSColor

    private static let offlinePlotValue: Double = 2000

    var body: some View {
        GeometryReader { geo in
            let values = samples.map { $0.latencyMs ?? Self.offlinePlotValue }
            let maxValue = max(values.max() ?? 1, 1)
            Path { path in
                guard values.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(values.count - 1)
                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geo.size.height - CGFloat(value / maxValue) * geo.size.height
                    let point = CGPoint(x: x, y: y)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            .stroke(Color(nsColor: color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }
}
