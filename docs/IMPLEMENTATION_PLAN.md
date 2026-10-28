# ADRIAN TV — Implementation Plan

*Living document — updated as phases complete. See docs/REPOSITORY_EVALUATION.md
for the foundation decision.*

## Foundation decision

Original Flutter codebase (current workspace), media_kit playback, clubTivi
(Apache-2.0) as optional licensed code donor, OpenIPTV/crispy-tivi as read-only
design reference. iptv-org data for dev fixtures only, never shipped content.

## Architecture

```
lib/
  main.dart                  # bootstrap: prefs, riverpod overrides, media_kit
  app/
    adrian_tv_app.dart       # MaterialApp.router + dark theme
    router.dart              # go_router: splash, shell branches, /player/:id
  core/
    theme/app_theme.dart     # cinematic dark palette, TV focus visuals
    widgets/brand.dart       # BrandMark / BrandWordmark (vector, original)
  data/
    models/                  # Channel, ContentSource, Programme, WatchProgress
    parsers/                 # M3uParser, XmltvParser + EpgIndex
    local/                   # AppPreferences (shared_preferences JSON)
    repositories/            # ChannelRepository (fetch + disk cache)
    services/                # EpgService (XMLTV fetch, demo schedule synth)
  features/
    providers/               # Riverpod wiring (no codegen)
    splash|shell|home|channels|epg|player|search|settings/
```

Key decisions:
- Plain immutable Equatable models + hand-written Riverpod providers — avoids
  build_runner/freezed/drift codegen in the critical path (drift remains a
  candidate when the catalogue grows; see Phase 6 notes).
- Sources are user-configured; only the clearly-labelled bundled demo playlist
  (public test streams) ships with the app. No credentials in prefs; a
  secure-storage path is reserved for Xtream credentials.
- A failing playlist/EPG source degrades to an empty list + in-app warning;
  playback errors surface with retry, never a silent black screen.
- Responsive shell: bottom NavigationBar on phones, NavigationRail at >= 900dp
  (Android TV). Focus-glow widgets prepared for Phase 5 D-pad work.

## Phases

### Phase 1 — Audit & research — DONE (2026-10-28)
- Workspace audited; repos evaluated; both docs written.

### Phase 2 — Foundation — DONE (2026-10-28)
- pubspec fixed (removed non-redistributable GoogleSans; runtime Inter via
  google_fonts; demo assets registered).
- Original branding generated (icon, splash mark, wordmark) + vector brand
  widgets; dark theme; router + responsive shell; Riverpod bootstrap.

### Phase 3 — Live TV — DONE (2026-10-28)
- [x] M3U parser (EXTINF attrs, EXTGRP, dedupe, tolerant)
- [x] XMLTV parser + EpgIndex (now/upcoming)
- [x] Source model + preferences persistence + demo source
- [x] ChannelRepository with disk cache + timeouts
- [x] EpgService (XMLTV fetch + demo schedule synthesis)
- [x] Channels screen: groups, filter, favourites, grid/list toggle
- [x] Player screen (media_kit): controls, error/retry, wake-lock, up-next
- [x] Guide screen (EPG): current/next per channel with progress, tap-to-play
- [x] Settings: source management (add/remove/enable remote M3U + EPG URL)

### Phase 4 — Streaming experience — DONE (2026-10-28)
- [x] Cinematic home: featured hero, continue-watching, favourites, group rails
- [x] Search across channels/groups with empty & loading states
- [x] Watch history + continue watching
- [ ] Movies/series catalogue view — deferred: no bundled provider supports
      VOD; adapter slot exists in ContentSource for authorised providers later.

### Phase 5 — Android TV — PARTIAL
- [x] Leanback launcher intent + touchscreen-not-required manifest flags
- [x] Wide-screen rail layout at >= 900dp
- [ ] Full D-pad focus map audit + TV text input (needs a TV emulator/device
      session; no Android SDK is installed in the current environment)

### Phase 6 — Hardening — PARTIAL
- [x] Unit tests for parsers/models/stores; widget tests for key screens
      (22 tests, all passing; flutter analyze clean)
- [x] Security basics: http(s)-only source validation, no credentials stored,
      per-source failure isolation
- [ ] Playlist scale test (>5k channels) and drift migration decision
- [ ] Native build verification (blocked: Android SDK / VS C++ absent)

### Phase 7 — Release preparation — PARTIAL
- [x] README with setup, features, limitations, legal notes
- [ ] Signing config + build instructions verification (needs Android SDK)

## Risks

- media_kit HLS reliability on low-end Android TV hardware is unproven for us;
  escape hatch is a self-written Media3 platform view (no GPL code).
- clubTivi dormancy: adopt its algorithms piecemeal with attribution, do not
  depend on it upstream.
- iptv-org streams must never ship in the product (legal, not technical).
- Android build not yet attempted in this environment (SDK availability to be
  checked in Phase 7).
