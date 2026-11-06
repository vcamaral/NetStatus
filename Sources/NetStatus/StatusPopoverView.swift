import SwiftUI

struct StatusPopoverView: View {
    @ObservedObject var monitor: NetworkMonitor
    let updater: Updater

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            historySection
            Divider()

            Button("Check Now") { monitor.checkNow() }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)

            Divider()

            HStack {
                Text("Version \(Updater.currentVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Check for Updates…") { updater.checkNow() }
                    .buttonStyle(.link)
                    .font(.caption)
            }

            Button("Quit NetStatus") { NSApp.terminate(nil) }
                .buttonStyle(.link)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(nsColor: StatusIcon.color(for: monitor.status)))
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LAST 5 MINUTES")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Sparkline(samples: monitor.history, color: StatusIcon.color(for: monitor.status))
                .frame(height: 32)
            Text(lastCheckText)
                .font(.caption)
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
