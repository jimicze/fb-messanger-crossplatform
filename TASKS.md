# TASKS.md — Messenger X

## 🐛 Bugs

### [BUG-001] Cold-start offline mode shows error page instead of cached content
- **Priority:** High
- **Status:** ✅ Fixed
- **Description:** When the app is opened without internet connection, the WebView displays a native browser error page ("Safari cannot open the page" / ERR_INTERNET_DISCONNECTED) instead of loading the last cached snapshot.
- **Root cause:** `load_snapshot` IPC command exists but is never called automatically on startup. No fallback mechanism when `messenger.com` fails to load.
- **Additional issue:** The 60-second snapshot timer doesn't check `navigator.onLine` — it can overwrite the last good snapshot with an offline/error page snapshot.
- **Fix (implemented):**
  1. `is_likely_online()` check at startup — if offline, loads local `index.html` instead of messenger.com
  2. Cached snapshot injected into webview via `document.write()` with offline banner
  3. Auto-reconnect timer (15s) redirects to messenger.com when connectivity is restored
  4. `SNAPSHOT_TRIGGER_SCRIPT` now guards against offline/error pages (checks `navigator.onLine` + URL)

### [BUG-002] Offline message sync between web and mobile
- **Priority:** Low
- **Status:** ⏭️ Won't Fix (Facebook-side issue)
- **Description:** Messages sent while in flaky network conditions are sometimes visible on web but not synced to mobile app. This is a Facebook server-side sync issue — Messenger X does not intercept or modify message sending in any way.

### [BUG-003] Windows SmartScreen blocks v0.1.4 installer as unrecognized app
- **Priority:** High
- **Status:** 🔴 Open
- **Description:** NSIS installer for v0.1.4 triggers Windows SmartScreen warning ("Systém Windows ochránil váš počítač" / "Windows protected your PC") — SmartScreen filter blocks execution of the unsigned app. v0.1.0 did not exhibit this issue.
- **Root cause:** The .exe is not code-signed with a valid Windows Authenticode certificate. SmartScreen assigns reputation based on publisher identity — unsigned apps are flagged as potentially dangerous.
- **Fix:** Requires FEAT-003 (Windows Authenticode code signing). Until then, users must click "More info" → "Run anyway" to proceed.
- **Related:** FEAT-003

### [BUG-004] App icon has white corners on Windows desktop shortcut
- **Priority:** Medium
- **Status:** ✅ Fixed
- **Description:** The Messenger X desktop shortcut icon on Windows displays white corners instead of transparent ones. The icon.ico file appears to have opaque white background in rounded corner areas instead of alpha transparency.
- **Root cause:** The AND mask in the BMP layers of icon.ico was incorrect — AND bit was 0 (opaque) for corner pixels that should be transparent (alpha=0). Pillow's ICO save does not generate correct AND masks for 32-bit BMP layers.
- **Fix (implemented):**
  1. Rebuilt icon.ico manually using `struct.pack` — all BMP layers (16, 24, 32, 48) now have AND bit=1 where alpha=0 and AND bit=0 where alpha>0
  2. AND mask rows padded to 4-byte boundaries; pixel data stored as BGRA bottom-up
  3. Regenerated all PNG icons with alpha threshold cleanup to ensure clean transparency edges
  4. Released as v0.2.3

---

## ✨ Feature Requests

### [FEAT-001] i18n — System language localization
- **Priority:** Medium
- **Status:** ✅ Done
- **Description:** The app has ~30 hardcoded English strings in native UI (tray tooltip, loading screen, offline banner, settings window, confirmation dialogs, NSIS installer). These should adapt to the system language.
- **Languages supported:** English, Czech
- **Implementation:**
  1. `sys-locale = "0.3"` crate detects system locale (e.g. `cs-CZ` → `cs`)
  2. `services/locale.rs`: `detect_locale()`, `Translations` struct, `get_translations()`, `english()` + `czech()` functions
  3. `commands.rs`: `get_translations()` IPC command returns `HashMap<String, String>`
  4. `lib.rs`: tray tooltip, offline banner, loading offline text all use translated strings at build time
  5. `settings/settings.ts`: `applyTranslations()` called at DOMContentLoaded, updates h1/h2/labels/buttons/hints; logout confirm uses translated text
  - Note: Translation strings live in Rust code (not JSON files) — simpler for 2 languages, can migrate to JSON if more languages are added

### [FEAT-002] Auto-update support
- **Priority:** Medium
- **Status:** ✅ Done
- **Description:** Integrate Tauri updater plugin for automatic update checks and in-app update flow.
- **Implementation:**
  1. `tauri-plugin-updater = "2"` + `tauri-plugin-process = "2"` in Cargo.toml
  2. `tauri.conf.json`: `createUpdaterArtifacts: true`, `plugins.updater.pubkey` + GitHub Releases endpoint
  3. `capabilities/default.json`: added `updater:default` + `process:default` permissions
  4. `lib.rs`: registered updater + process plugins
  5. `@tauri-apps/plugin-updater` + `@tauri-apps/plugin-process` npm packages
  6. Settings UI: "Updates" section with "Check for updates" button, download progress, "Install & Restart" button
  7. `locale.rs`: 9 new i18n strings (en + cs) for update UI
  8. `commands.rs`: added translation keys for update strings
  9. `release.yml`: `TAURI_SIGNING_PRIVATE_KEY` env var + `includeUpdaterJson: true`
  10. Signing keypair generated at `~/.tauri/messengerx.key` (private) + `.key.pub` (public)
- **⚠️ Required GitHub secret:** `TAURI_SIGNING_PRIVATE_KEY` — must be set in repo Settings → Secrets before CI will produce signed update artifacts

### [FEAT-003] Code signing (SignPath.io + Apple notarization)
- **Priority:** High
- **Status:** 📋 Planned
- **Description:** Sign release builds to eliminate OS security warnings (Windows SmartScreen, macOS Gatekeeper).
- **Windows:** Use SignPath.io (free for open source) for Authenticode OV code signing via GitHub Actions
  - Register at https://signpath.io/open-source
  - Integrates as a GitHub Action step after build
  - Resolves BUG-003 (SmartScreen "unrecognized app" warning)
- **macOS:** Apple notarization via Xcode + Apple Developer account ($99/yr)
  - `APPLE_CERTIFICATE`, `APPLE_ID`, `APPLE_PASSWORD`, `APPLE_TEAM_ID` secrets
  - Already stubbed out (commented) in `release.yml`

### [FEAT-005] Package manager distribution (winget, apt, brew)
- **Priority:** Medium
- **Status:** 📋 Planned
- **Description:** Publish Messenger X to platform-native package managers for easier installation.
- **winget (Windows)**
  - Submit manifest to https://github.com/microsoft/winget-pkgs
  - Users install via `winget install messengerx`
  - Can automate manifest PR via `vedantmgoyal9/winget-releaser` GitHub Action
  - Note: does NOT resolve SmartScreen — still needs FEAT-003
- **Homebrew (macOS)**
  - Create a tap: `jimicze/homebrew-tap` with Cask formula
  - Users install via `brew install --cask jimicze/tap/messengerx`
  - Formula points to `.dmg` from GitHub Releases
  - Can automate via `dawidd6/action-homebrew-bump-cask` or custom workflow
- **APT repository (Debian/Ubuntu/Mint)**
  - Host a PPA or use GitHub Pages as apt repo with `.deb` packages
  - Users: `sudo add-apt-repository ppa:jimicze/messengerx && sudo apt install messengerx`
  - Alternative: Packagecloud.io (free for open source) or Gemfury
  - Sign repo with GPG key for `apt` trust

### [FEAT-004] System notification styles (banners, alerts, sounds)
- **Priority:** Medium
- **Status:** ✅ Done (desktop-supported features)
- **Description:** Enhanced notification dispatch with platform-appropriate sounds, grouping, and silent mode.
- **Implementation:**
  - `notification.rs`: `show_notification()` now accepts `silent` param; uses `.auto_cancel()`, `.group(tag)`, `.silent()`, platform-specific `.sound()` (macOS=`"default"`, Linux=`"message-new-instant"`, Windows=`"Default"`)
  - `NOTIFICATION_OVERRIDE_SCRIPT` in `lib.rs`: forwards `silent` flag from browser `Notification` options
  - `commands.rs`: `send_notification` has new `silent: bool` parameter
  - Tray icon click handler: `on_tray_icon_event` → `show()` + `unminimize()` + `set_focus()` on main window
- **Limitations (desktop/Tauri):**
  - `.group()`, `.auto_cancel()`, `.silent()` are primarily mobile APIs — on desktop they may be no-ops but cause no harm
  - Action buttons (quick-reply) not available on desktop via `tauri-plugin-notification`
  - Notification click callback not available — handled via tray icon click instead
