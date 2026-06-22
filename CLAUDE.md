# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
# Build (debug)
swift build -c debug --package-path FocusFlow

# Build (release)
swift build -c release --package-path FocusFlow

# Run all tests
swift test --package-path FocusFlow

# Run a single test
swift test --package-path FocusFlow --filter FocusFlowTests/testSoundCatalogCount

# Build and run the app
swift run --package-path FocusFlow

# Package app for distribution (ad-hoc signed, outputs dist/FocusFlow.app.zip)
bash scripts/package_app.sh
```

## CI/CD

Two GitHub Actions workflows on `macos-15` runners:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `macos-ci.yml` | push/PR to main, `v*` tags, manual | Build → test → package .app → upload artifact; creates GitHub Release on `v*` tags |
| `app-store-submit.yml` | `appstore-v*` tags, manual | Build → test → import certs/profiles → archive → export → optionally upload to App Store Connect |

**App Store secrets** live in the `app-store` GitHub Environment (certificates, provisioning profile, App Store Connect API key). The `package_app.sh` script uses ad-hoc signing — only suitable for CI artifacts and local smoke testing. Release distribution needs Developer ID signing + notarization.

## Project Overview

FocusFlow is a **macOS menu bar app** (SwiftUI + AppKit, min macOS 13) that creates a "digital workstation atmosphere" — ambient sound mixer + macOS Focus automation + IM status sync + app blocking + Pomodoro timer. Target users: developers, remote workers, creatives, students.

**Architecture**: Single binary, no backend server, no user accounts, Local-First, no analytics SDK.

## Architecture — Manager Pattern

The app uses a **singleton Manager pattern** (`@MainActor final class`, accessed via `.shared`). Each manager owns one domain:

| Manager | Responsibility |
|---------|---------------|
| `AudioManager` | AVAudioEngine lifecycle, multi-track mixing (max 3 sounds), fade in/out, volume per-sound + master |
| `TimerManager` | Pomodoro countdown (wall-clock based via `endDate`, not tick-counting), posts `.focusTimerDidFinish` |
| `FocusStateManager` | Focus session orchestrator — observes timer finish, sequences start/end actions (audio → focus mode → IM → app blocking → calendar → timer), reads automation flags from `PreferencesManager`, calls `StatisticsManager` to record sessions |
| `PreferencesManager` | UserDefaults-backed settings with `@Published`, `SMAppService` login item toggle, `resetAll()` resets both storage AND in-memory state |
| `IntegrationManager` | Slack/Discord/Teams OAuth via Cloudflare Workers proxy, status sync (parallel via `withTaskGroup`), `KeychainManager` for token storage |
| `ODRManager` | On-Demand Resources — delegate-based `URLSession` download from Cloudflare R2 CDN, progress tracking, local cache at `~/Library/Application Support/FocusFlow/Sounds/` |
| `PanelStateManager` | Shared UI state between NSPopover and detached FloatingWidgetWindow (selected sounds, volumes, duration, active tab) |
| `StatisticsManager` | Session history in UserDefaults (JSON-encoded `[FocusSession]`), today/week/month aggregates, 30-day heatmap data |
| `MenuBarController` | NSStatusItem, NSPopover, FloatingWidgetWindow, context menu, global event monitor for outside-click dismissal |

**Key files**: `Models.swift` (Sound catalog, FocusSession, Soundscape presets, enums), `FocusFlowApp.swift` (AppDelegate entry point, onboarding window, SettingsWindowController).

## Critical Patterns & Gotchas

### @ObservedObject for singletons, never @StateObject
All views use `@ObservedObject private var foo = FooManager.shared`. Never `@StateObject` — that implies ownership and causes lifecycle issues with shared singletons.

### Audio engine restart protocol
`AVAudioEngine` must be stopped before modifying the node graph. `AudioManager.playSound()` follows this sequence: pause players → stop engine → attach new node → restart engine → re-schedule existing buffers (skipping sounds in `fadingOutSoundIds`) → schedule and play new buffer. Do not break this ordering.

### stopSound cleanup is immediate
`stopSound()` immediately removes from `activeSounds`/`players`/`buffers` and inserts into `fadingOutSoundIds`. The fade-out (1s) and node teardown happen asynchronously. The `fadingOutSoundIds` set prevents re-scheduling during engine restart.

### Session recording: capture BEFORE timer.stop()
`TimerManager.stop()` zeroes `totalSeconds`. Always capture duration data before calling `stop()`. `FocusStateManager` stores `currentSessionStart` and `currentSessionDurationSeconds` at session start, and `endFocus()` captures them before the cleanup sequence.

### Timer uses wall-clock, not tick counting
`TimerManager.tick()` computes `remainingSeconds = Int(endDate.timeIntervalSinceNow.rounded(.up))` instead of decrementing. This eliminates drift over long sessions. All display formatters guard with `max(0, remainingSeconds)` to prevent negative display during the race between tick detection and stop.

### ODR download + playback must be sequential
Download and playback for a Pro sound must happen in a single `Task {}` — download first, `await` it, then `guard panel.selectedSounds.contains(soundId)` before playing. Separate Tasks cause double-download and playback-after-cancel bugs. **ODR pre-download is centralized in `FocusStateManager.startFocus()`** — all focus session entry points (UI button, quick start, hotkey) go through this path. `AudioManager.loadBuffer()` keeps a direct-download fallback for edge cases (e.g. Soundscape presets applied outside a focus session).

### Calendar events: guard against nil defaultCalendar
`EKEventStore.defaultCalendarForNewEvents` can be nil (user has no calendar configured). Always guard before assigning to `event.calendar`.

### NSStatusItem cleanup
`cleanup()` must call `NSStatusBar.system.removeStatusItem(item)` before setting `statusItem = nil`. Otherwise the icon persists after termination.

### Esc key = close panel (never end focus)
The keyboard handler makes Esc always close the popover. Ending a focus session requires an explicit button click. This prevents accidental session loss.

### Focus automation flags live in PreferencesManager
`FocusStateManager.startFocus()` and `endFocus()` read automation flags directly from `PreferencesManager.shared.autoEnableFocus` / `autoBlockApps` / `autoSyncCalendar`. Do NOT duplicate these as separate properties on FocusStateManager — that was a bug where the features silently never activated.

### IntegrationManager OAuth is proxy-mediated (not real PKCE)
Despite the method name `performOAuthPKCE`, all OAuth flows go through a Cloudflare Workers proxy (`focusflow-proxy.workers.dev`). The proxy handles the full OAuth handshake including PKCE. Slack, Discord, and Teams all use the same flow — there is no separate "standard" OAuth path.

### Audio fade uses asyncAfter, not sample-accurate scheduling
Fade-in/out uses `DispatchQueue.main.asyncAfter` at ~30 fps. This is adequate for ambient noise but not sample-accurate. If audio pops are reported, the fix is to use `AVAudioPlayerNode.scheduleSegment()` or parameter automation on the render thread.

### Settings window dedup
`SettingsWindowController.show()` checks for and closes any other window titled "FocusFlow 偏好设置" before opening. This prevents a duplicate from the SwiftUI `Settings` scene (which handles Cmd+, internally) appearing alongside the programmatic window (opened from the menu bar).

### PreferencesManager didSet during init
`launchAtLogin.didSet` calls `SMAppService` which is wasteful during init. A `didFinishInit` flag suppresses this until after init completes.

### ProgressPieImage: modern NSImage API
Uses `NSImage(size:flipped:drawingHandler:)` — `lockFocus()`/`unlockFocus()` are deprecated in macOS 14+.

## UI Hierarchy

```
NSStatusItem (menu bar icon)
  ├── left-click → toggle NSPopover (transient, 320×520)
  │     └── PopoverContentView (SwiftUI)
  │           ├── Sound grid / Presets (LazyVGrid, 4-column)
  │           ├── Active sounds (ForEach over audioManager.activeSounds.keys)
  │           ├── Focus button (keyboardShortcut: .return, disabled during custom duration popover)
  │           └── Keyboard handling (Esc/Enter/Space via NSEvent.addLocalMonitorForEvents)
  ├── right-click → popUpContextMenu (quick start / settings / quit)
  └── Pin button → close popover, show FloatingWidgetWindow (.floating level, borderless, rounded)
        └── PopoverContentView (shared view, @ObservedObject on all managers)
```

## Settings Window

`SettingsWindowController` holds a single `NSWindow` (isReleasedWhenClosed=false, reused). SwiftUI `SettingsView` with sidebar tabs — General / Sounds / Integrations / Statistics / About. Each tab is a separate `*SettingsView` struct with `@ObservedObject` on relevant managers.

## Data Flow — Focus Session Lifecycle

1. User configures sounds + duration in panel → `PanelStateManager`
2. Press "开始专注" → `FocusStateManager.startFocus()`:
   - Sets `focusState = .focusing(endTime:duration:)`, captures `currentSessionStart`/`currentSessionDurationSeconds`
   - Audio plays (via `AudioManager.playSound` per soundId)
   - macOS Focus enabled (Shortcuts URL scheme)
   - IM status synced (parallel, silent on failure)
   - App blocking (FamilyControls, stub)
   - Calendar busy event written (EventKit, guarded for nil calendar)
   - Timer starts (wall-clock based)
3. Timer ticks → `Tick()` updates `remainingSeconds` → when ≤0: `stop()`, post `.focusTimerDidFinish`
4. `FocusStateManager` observes notification → `endFocus()`:
   - Captures session data (before `timerManager.stop()` zeroes it)
   - Stops audio, disables focus mode, restores IM, stops timer
   - Records session via `StatisticsManager.recordSession()`
5. `StatisticsManager` appends to in-memory array, encodes to UserDefaults JSON, recalculates today/week/month totals

## Sound Catalog

Defined as `SoundCatalog.allSounds` (static `[Sound]`, 24 sounds). Free tier: white_noise, rain_light, cafe (isFree=true, isDownloaded=true, bundled in app). Pro tier: 21 sounds (isFree=false, downloaded on-demand from `cdn.focusflow.app/sounds/{fileName}` via ODRManager). Soundscape presets are in `Soundscape.presets` (5 built-in mixes).

## CDN / Sound File Hosting

Pro sound files (.aac, 24 total) are served from **GitHub Releases** — zero cost, no bank card needed.

**Download URL** (`Models.swift`):
```
https://github.com/ZhangShiCheng3D/FocusFlow/releases/download/sounds-v3/{fileName}
```

**CI upload**: `.github/workflows/upload-sounds.yml` triggers on `sounds-v*` tags or manual dispatch. Uses `scripts/ci_generate_sounds.sh` (ffmpeg synthesis on macOS runner) → uploads all 24 .aac files as release assets. The release `tag_name` follows the pushed tag, so each `sounds-v*` tag publishes its own release.

**To regenerate sounds**: push a new tag like `sounds-v3`, which both generates the assets and creates the matching release. Then update the tag name in `Models.swift` (`remoteURL`).

**Local generation** (Mac only): `bash scripts/generate_sounds.sh` requires `brew install ffmpeg`.

**Cloudflare backup** (optional): API token in `.env.cloudflare` (gitignored), Account ID `fb6e809e6014f60d4bfc5e25747d6d7d`. R2 bucket not yet created — manual enable needed via dashboard.

## App Bundle & Signing

`FocusFlow.entitlements` — requires hardened runtime and app sandbox for App Store. `scripts/package_app.sh` handles release packaging locally (ad-hoc signed). App Store submission uses `scripts/submit_app_store.sh` with proper signing identities and provisioning profiles from CI secrets.

## Test Coverage

Tests in `FocusFlowTests.swift` cover: Sound catalog integrity (count, uniqueness, categories), Soundscape presets (validity, max mix count), FocusSession (creation, Codable round-trip, actual duration), TimerPresets defaults, IntegrationStatus errors (descriptions, silent flag), Preferences defaults, Timer progress clamping, ODR URL generation, and bundled download state.

## Keychain Token Storage

`KeychainManager` uses `SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete` with `kSecAttrAccessibleAfterFirstUnlock`. If the Keychain is unavailable (simulator, sandbox edge cases) it falls back to a **session-scoped in-memory dict** (lock-guarded) — never plaintext on disk. Consequence: in that degraded state tokens don't survive an app restart and the user re-authorizes. On a successful Keychain read/write, any stale in-memory copy is dropped.
