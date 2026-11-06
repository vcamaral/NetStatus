<h1><img src="assets/icon.png" width="64" height="64" align="absmiddle" alt=""> NetStatus</h1>

A menu bar app for macOS that tells you, at a glance, whether your internet is working.

A plain colored dot replaces the usual Wi-Fi icon so the two are never confused: green means
everything's fine, orange means the connection is slow or flaky, red means it's down, and gray
pulsing means it's checking right now. Click it for latency and a short history; you also get a
notification the moment the connection drops or comes back, no setup needed.

## Install

```bash
brew install --cask vcamaral/tap/netstatus
```

Or build from source:

```bash
gh repo clone vcamaral/NetStatus ~/Code/netstatus
~/Code/netstatus/install.sh
```

Requires macOS 14+ and Apple's Command Line Tools (`install.sh` offers to install them). No other
dependency — just the system Network framework and a plain HTTPS request.

### First launch

NetStatus isn't notarized yet, so macOS blocks it the first time. To allow it:

1. Open NetStatus and dismiss the warning.
2. Go to **System Settings › Privacy & Security**, scroll down and click **Open Anyway**.

The Homebrew cask skips this step by removing the quarantine flag itself.

## How it decides

Every 8 seconds (and right away whenever the network interface changes), NetStatus sends a tiny
HTTPS request to a stable Apple-hosted file and times the response:

- Under 400ms → **online**
- 400ms or more → **slow**
- No response within 4s, or an error → **offline**

The last 30 checks are kept in memory for the popover's sparkline; nothing is sent anywhere else,
and the only network traffic NetStatus generates is this probe plus, optionally, an update check.

## Updates

A build from a clone updates itself: it checks the git remote once a day, and when
there are new commits with no local changes in the way, it pulls, rebuilds and restarts in the
background — no prompt. It skips updating while the clone has uncommitted changes. Keep the clone
where you installed from; the log of the last update is in `~/Library/Logs/NetStatus-update.log`.

Installed from the Homebrew cask or a downloaded DMG, **Check for Updates…** in the popover looks
at the latest GitHub release and tells you how to get it (`brew upgrade --cask netstatus`, or a
new DMG) — it never updates itself from there, so it only ever goes online when you ask.

To package the DMG: `./scripts/make-dmg.sh` builds `build/NetStatus.dmg`. To publish a release,
bump `CFBundleShortVersionString` in `Info.plist`, commit, and run `./scripts/release.sh
[notes.md]`: it creates the GitHub release and updates the
[Homebrew cask](https://github.com/vcamaral/homebrew-tap).

## Layout

| File | Role |
|---|---|
| `NetworkMonitor.swift` | `NWPathMonitor` + periodic HTTPS probe, latency history, status classification |
| `StatusIcon.swift` | Draws the menu bar dot for each status |
| `StatusPopoverView.swift` | The popover: status, sparkline, actions and settings |
| `Notifier` (in `AppDelegate.swift`) | Posts a notification on drop/reconnect |
| `Updater.swift` | Self-update from the git clone, or a release check for cask/DMG installs |
| `AppDelegate.swift` | Menu bar item, popover and wiring |

## License

MIT — see [LICENSE](LICENSE).
