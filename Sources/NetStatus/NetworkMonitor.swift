import Foundation
import Network

enum ConnectionStatus: Equatable {
    case online
    case slow
    case offline
    case checking
}

struct Sample: Identifiable {
    let id = UUID()
    let date: Date
    /// nil means the check failed (offline).
    let latencyMs: Double?
}

/// Polls a reliable HTTPS endpoint on a timer and watches the network interface for changes,
/// classifying the result as online / slow / offline and keeping a short latency history.
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var status: ConnectionStatus = .checking
    @Published private(set) var latencyMs: Double?
    @Published private(set) var lastCheck: Date?
    @Published private(set) var history: [Sample] = []

    /// Called after a check completes with a status different from the one before it (never fired
    /// for the initial .checking -> first-result transition).
    var onStatusChange: ((_ previous: ConnectionStatus, _ new: ConnectionStatus) -> Void)?

    private static let checkInterval: TimeInterval = 8
    private static let historyLimit = 30
    private static let slowThresholdMs: Double = 400
    private static let timeout: TimeInterval = 4
    /// A small, stable file Apple serves over HTTPS; used elsewhere as a captive-portal/connectivity probe.
    private static let checkURL = URL(string: "https://www.apple.com/library/test/success.html")!

    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "com.vcamaral.netstatus.path")
    private var timer: Timer?
    private var isChecking = false
    private var lastPathSatisfied = true

    func start() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.handlePathUpdate(path) }
        }
        pathMonitor.start(queue: pathQueue)

        Task { await check() }
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
    }

    func checkNow() {
        Task { await check(force: true) }
    }

    // MARK: - Private

    private func handlePathUpdate(_ path: NWPath) {
        let satisfied = path.status == .satisfied
        guard satisfied != lastPathSatisfied else { return }
        lastPathSatisfied = satisfied
        Task { await check() }
    }

    private func check(force: Bool = false) async {
        guard !isChecking || force else { return }
        isChecking = true
        defer { isChecking = false }

        let previous = status
        status = .checking

        var request = URLRequest(url: Self.checkURL)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = Self.timeout

        let start = Date()
        var newLatency: Double?
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
                throw URLError(.badServerResponse)
            }
            newLatency = Date().timeIntervalSince(start) * 1000
            status = newLatency! < Self.slowThresholdMs ? .online : .slow
        } catch {
            newLatency = nil
            status = .offline
        }

        latencyMs = newLatency
        lastCheck = Date()
        record(latencyMs: newLatency)

        if previous != .checking, previous != status {
            onStatusChange?(previous, status)
        }
    }

    private func record(latencyMs: Double?) {
        history.append(Sample(date: Date(), latencyMs: latencyMs))
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
    }
}
