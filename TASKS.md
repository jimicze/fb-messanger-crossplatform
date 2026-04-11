# TASKS.md — Messenger X

## 🐛 Bugs

### [BUG-001] Cold-start offline mode shows error page instead of cached content
- **Priority:** High
- **Status:** ✅ Fixed
- **Description:** When the app is opened without internet connection, the WebView displays a native browser error page ("Safari cannot open the page" / ERR_INTERNET_DISCONNECTED) instead of loading the last cached snapshot.
- **Root cause:** `load_snapshot` IPC command exists but is never called automatically on startup. No fallback mechanism when `messenger.com` fails to load.
- **Fix (implemented):**
  1. `is_likely_online()` check at startup — if offline, loads local `index.html` instead of messenger.com
  2. Cached snapshot injected into webview via `document.write()` with offline banner
  3. Auto-reconnect timer (15s) redirects to messenger.com when connectivity is restored
  4. `SNAPSHOT_TRIGGER_SCRIPT` now guards against offline/error pages (checks `navigator.onLine` + URL)

### [BUG-002] Offline message sync between web and mobile
- **Priority:** Low
- **Status:** ⏭️ Won't Fix (Facebook-side issue)
- **Description:** Messages sent while in flaky network conditions are sometimes visible on web but not synced to mobile app. This is a Facebook server-side sync issue — Messenger X does not intercept or modify message sending in any way.

### [BUG-003] Windows SmartScreen blocks installer as unrecognized app
- **Priority:** High
- **Status:** 🔴 Open
- **Description:** NSIS installer triggers Windows SmartScreen warning ("Windows protected your PC") — SmartScreen blocks execution of the unsigned app.
- **Root cause:** The .exe is not code-signed with a valid Windows Authenticode certificate.
- **Fix:** Requires FEAT-003 (Windows Authenticode code signing). Until then, users must click "More info" → "Run anyway".
- **Related:** FEAT-003

### [BUG-004] App icon has white corners on Windows desktop shortcut
- **Priority:** Medium
- **Status:** ✅ Fixed (v0.2.3)
- **Description:** Desktop shortcut icon on Windows displays white corners instead of transparent ones.
- **Root cause:** Incorrect AND mask in BMP layers of icon.ico — AND bit was 0 for transparent pixels. Pillow's ICO save does not generate correct AND masks.
- **Fix:** Rebuilt icon.ico manually with correct AND masks; regenerated all PNG icons with alpha threshold cleanup.

### [BUG-005] Settings window unreachable
- **Priority:** High
- **Status:** ✅ Fixed (v0.2.4)
- **Description:** After launching the app, users had no way to reach the Settings window.
- **Fix:**
  - Tray context menu with "Show Window", "Settings", "Quit" (localized en/cs)
  - macOS app menu bar: Messenger X → Settings (⌘,), Quit (⌘Q); Edit → standard items
  - Keyboard shortcut Cmd+, / Ctrl+, injected into WebView via JS
  - `open_settings` IPC command + `open_settings_window()` helper

### [BUG-006] latest.json race condition in CI
- **Priority:** High
- **Status:** ✅ Fixed (v0.2.4)
- **Description:** Parallel matrix jobs each generated their own `latest.json` — first uploader won, rest got `already_exists` error. The uploaded manifest was incomplete.
- **Fix:** Three-phase workflow: (1) create-release, (2) build-tauri with `includeUpdaterJson: false`, (3) `publish-updater` job generates single complete `latest.json` after all builds.

### [BUG-007] Tray context menu not showing on Windows
- **Priority:** High
- **Status:** ✅ Fixed (v0.2.5)
- **Description:** Right-click on tray icon did not show context menu on Windows.
- **Root cause:** `on_tray_icon_event` matched ALL clicks including right-click → window stole focus → OS menu closed before rendering.
- **Fix:** Filter only `MouseButton::Left` + `MouseButtonState::Up` in the handler.

### [BUG-008] Settings window broken on Windows (MIME type enforcement)
- **Priority:** Critical
- **Status:** ✅ Fixed (v0.2.7)
- **Description:** Settings window completely non-functional on Windows — no toggles, no zoom, no updates worked.
- **Root cause:** `<script type="module" src="settings.ts">` — WebView2 (Chromium) rejects `.ts` files served as `video/mp2t` MIME type. WebKit on macOS was lenient so bug was invisible during development.
- **Fix:** Replaced with inline `<script>` using `window.__TAURI__.core.invoke` directly. Added `check_for_update()` and `install_update()` Rust IPC commands.

### [BUG-009] Settings window buttons non-functional (withGlobalTauri)
- **Priority:** Critical
- **Status:** ✅ Fixed (v0.2.8)
- **Description:** Zoom +/- buttons and "Check for updates" button render but do nothing on any platform.
- **Root cause:** `app.withGlobalTauri` not set in `tauri.conf.json` → `window.__TAURI__` is `undefined` in page-level inline scripts → `init()` returns early at the guard check → no event listeners attached.
- **Fix:** Added `"withGlobalTauri": true` to `app` section of `tauri.conf.json`. Also fixed `.update-status` CSS `transition: all` → `transition: color 0.2s`.

---

## ✨ Feature Requests

### [FEAT-001] i18n — System language localization
- **Priority:** Medium
- **Status:** ✅ Done (v0.1.4)
- **Description:** ~30 hardcoded English strings localized. Languages: English, Czech.
- **Implementation:** `sys-locale` crate, `services/locale.rs`, `get_translations()` IPC, settings UI fully localized.

### [FEAT-002] Auto-update support
- **Priority:** Medium
- **Status:** ✅ Done
- **Description:** Tauri updater plugin integrated with signing keypair, Settings UI section, CI generates `latest.json`.

### [FEAT-003] Code signing (SignPath.io + Apple notarization)
- **Priority:** High
- **Status:** 📋 Planned
- **Description:** Sign release builds to eliminate OS security warnings.
- **Windows:** SignPath.io (free for open source) for Authenticode OV code signing
- **macOS:** Apple notarization via Xcode + Apple Developer account ($99/yr)
- **Related:** Resolves BUG-003

### [FEAT-004] Enhanced notifications
- **Priority:** Medium
- **Status:** ✅ Done (v0.1.4)
- **Description:** Platform-specific sounds, silent mode, grouping, tray click handler to focus main window.

### [FEAT-005] Package manager distribution (winget, apt, brew)
- **Priority:** Medium
- **Status:** 📋 Planned
- **Description:** Publish to platform-native package managers.
- **winget:** Submit manifest to `microsoft/winget-pkgs`, automate with `vedantmgoyal9/winget-releaser`
- **Homebrew:** Create tap `jimicze/homebrew-tap` with Cask formula pointing to `.dmg`
- **APT:** Host PPA or use GitHub Pages as apt repo with `.deb` packages

### [FEAT-006] Notification settings
- **Priority:** Medium
- **Status:** ✅ Done (v0.2.8)
- **Description:** Added notification controls to Settings window.
- **Implementation:**
  - `AppSettings` extended with `notifications_enabled: bool` and `notification_sound: bool` (default `true`)
  - `send_notification` gating: if `!notifications_enabled` → early return; if `!notification_sound` → force `silent: true`
  - Settings UI: new "Notifications" section with two toggles
  - i18n: 3 new translation keys (en + cs)

### [FEAT-007] Auto-start at login + minimize to tray
- **Priority:** Medium
- **Status:** ✅ Done (v0.2.8)
- **Description:** App starts automatically at system boot, sits in tray, collects notifications in background.
- **Implementation:**
  - `tauri-plugin-autostart` integrated (macOS Login Items, Windows Registry, Linux `.desktop` in `~/.config/autostart/`)
  - `AppSettings` extended with `autostart: bool` and `start_minimized: bool` (default `false`)
  - Wrapper IPC commands: `set_autostart(enabled)` and `is_autostart_enabled()`
  - Main window: `.visible(!settings.start_minimized)` in builder
  - Settings UI: new "Startup" section with two toggles; autostart queries OS state on load
  - i18n: 3 new translation keys (en + cs)
  - Capabilities: added `autostart:default` permission
