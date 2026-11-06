import AppKit

/// Keeps NetStatus up to date from the git clone it was built from (build.sh stores the clone's path
/// in Info.plist): checks origin periodically and, when there are new commits with no local changes in
/// the way, pulls, rebuilds and restarts in the background with no prompt.
/// A copy installed from the Homebrew cask / DMG has no clone: Check for Updates… looks at GitHub
/// Releases instead, only when asked, so NetStatus never goes online on its own in that case.
@MainActor
final class Updater {
    private static let checkInterval: TimeInterval = 2 * 60 * 60
    private static let firstCheckDelay: TimeInterval = 60
    static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/NetStatus-update.log")

    private let sourceDir = Bundle.main.object(forInfoDictionaryKey: "NetStatusSourceDir") as? String
    private var checkTimer: Timer?
    private var isBusy = false
    /// A remote commit whose update failed: not retried automatically until something newer lands.
    private var failedCommit: String?

    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/vcamaral/NetStatus/releases/latest")!
    private static let releasePageURL = URL(string: "https://github.com/vcamaral/NetStatus/releases/latest")!

    static var currentCommit: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev"
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func start() {
        guard sourceDir != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.firstCheckDelay) { [weak self] in
            Task { await self?.checkAndUpdate(userInitiated: false) }
        }
        checkTimer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.checkAndUpdate(userInitiated: false) }
        }
    }

    /// From the popover: checks now, applying an update right away (from a clone) or offering the
    /// latest release (installed from the cask/DMG).
    func checkNow() {
        Task {
            if sourceDir == nil {
                await checkLatestRelease()
            } else {
                await checkAndUpdate(userInitiated: true)
            }
        }
    }

    // MARK: - Private

    private func checkAndUpdate(userInitiated: Bool) async {
        guard let sourceDir, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let fetch = await Self.shell("git fetch --quiet origin", in: sourceDir)
        guard fetch.status == 0 else {
            if userInitiated { showAlert("Não foi possível verificar atualizações.", details: fetch.output) }
            return
        }
        let remote = await Self.shell("git rev-parse --short @{u}", in: sourceDir).output
        guard remote != Self.currentCommit,
              await Self.shell("git merge-base --is-ancestor \(Self.currentCommit) @{u}", in: sourceDir).status == 0
        else {
            if userInitiated { showAlert("NetStatus já está atualizado.", details: "Versão \(Self.currentCommit)") }
            return
        }
        guard userInitiated || remote != failedCommit else { return }
        // Uncommitted changes mean someone is working in this clone: don't build their half-done code.
        guard await Self.shell("git status --porcelain --untracked-files=no", in: sourceDir).output.isEmpty else {
            if userInitiated {
                showAlert("NetStatus não pode atualizar agora.", details: "\(sourceDir) tem alterações não commitadas.")
            }
            return
        }

        // `build.sh install` quits this process and opens the new one on success.
        let build = await Self.shell(
            "git pull --ff-only --quiet && ./build.sh install > '\(Self.logURL.path)' 2>&1", in: sourceDir
        )
        if build.status != 0 {
            failedCommit = remote
            if userInitiated { showAlert("Não foi possível atualizar o NetStatus.", details: Self.logTail(or: build.output)) }
        }
    }

    /// Cask/DMG installs: compares this version with the latest GitHub release and points to it.
    private func checkLatestRelease() async {
        struct Release: Decodable { let tag_name: String }
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.latestReleaseAPI)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let latest = String(try JSONDecoder().decode(Release.self, from: data).tag_name.trimmingPrefix("v"))
            guard latest.compare(Self.currentVersion, options: .numeric) == .orderedDescending else {
                showAlert("NetStatus já está atualizado.", details: "Versão \(Self.currentVersion)")
                return
            }
            let alert = NSAlert()
            alert.messageText = "NetStatus \(latest) disponível."
            alert.informativeText = """
            Você está na versão \(Self.currentVersion).

            Instalado pelo Homebrew: rode "brew upgrade --cask netstatus".
            Senão, baixe o instalador na página da release.
            """
            alert.addButton(withTitle: "Abrir página")
            alert.addButton(withTitle: "Depois")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(Self.releasePageURL)
            }
        } catch {
            showAlert("Não foi possível verificar atualizações.", details: error.localizedDescription)
        }
    }

    private func showAlert(_ message: String, details: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = details
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func logTail(or fallback: String) -> String {
        let log = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        return log.isEmpty ? fallback : String(log.suffix(600))
    }

    /// A login shell gives git the same PATH and credential helpers as the user's terminal.
    private static func makeProcess(_ command: String, in dir: String) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = URL(fileURLWithPath: dir)
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"   // never hang waiting for a password
        process.environment = environment
        return process
    }

    private static func shell(_ command: String, in dir: String) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            let process = makeProcess(command, in: dir)
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: (process.terminationStatus, output))
            }
            do { try process.run() } catch { continuation.resume(returning: (-1, error.localizedDescription)) }
        }
    }
}
