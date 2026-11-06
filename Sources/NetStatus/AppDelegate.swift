import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = NetworkMonitor()
    private let updater = Updater()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var pulseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPopover()
        requestNotificationPermission()
        enableLaunchAtLoginOnFirstRun()

        monitor.onStatusChange = { [weak self] previous, new in
            self?.notifyIfNeeded(previous: previous, new: new)
        }
        monitor.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.updateIcon(for: status) }
            .store(in: &cancellables)

        monitor.start()
        updater.start()
    }

    // MARK: - Status item & popover

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = StatusIcon.dot(color: StatusIcon.color(for: .checking))
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
    }

    private func setUpPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: StatusPopoverView(monitor: monitor, updater: updater)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func updateIcon(for status: ConnectionStatus) {
        pulseTimer?.invalidate()
        pulseTimer = nil
        let color = StatusIcon.color(for: status)
        statusItem.button?.image = StatusIcon.dot(color: color)
        guard status == .checking else { return }

        var bright = false
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            bright.toggle()
            Task { @MainActor in
                self?.statusItem.button?.image = StatusIcon.dot(color: color, alpha: bright ? 1 : 0.35)
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyIfNeeded(previous: ConnectionStatus, new: ConnectionStatus) {
        guard UserDefaults.standard.object(forKey: "notifyEnabled") as? Bool ?? true else { return }
        let wasDown = previous == .offline
        let isDown = new == .offline
        guard wasDown != isDown else { return }

        let content = UNMutableNotificationContent()
        content.title = isDown ? "Sem internet" : "Internet voltou"
        content.body = isDown ? "A conexão caiu." : "A conexão foi restabelecida."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - First run

    /// Turns on "Open at Login" once; if the user turns it off later (in the popover), it stays off.
    private func enableLaunchAtLoginOnFirstRun() {
        let key = "didEnableLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        try? SMAppService.mainApp.register()
        UserDefaults.standard.set(true, forKey: key)
    }
}
