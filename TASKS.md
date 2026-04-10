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
- **Status:** 📋 Planned
- **Description:** Integrate Tauri updater plugin for automatic update checks and in-app update flow.

### [FEAT-003] Code signing
- **Priority:** Medium
- **Status:** 📋 Planned
- **Description:** Apple notarization + Windows Authenticode signing for release builds.

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
