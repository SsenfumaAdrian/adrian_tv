# ADRIAN TV — Repository Evaluation (Phase 1)

*Research date: 2026-10-28. Facts below were verified via fetched GitHub API data,
raw README/pubspec/LICENSE files, unless marked "could not verify". No repository
was built or executed, so runtime reliability scores reflect architecture and
issue signals only.*

## Purpose

Decide whether ADRIAN TV should fork an existing open-source streaming app or be
built original, using these repos as reference. ADRIAN TV targets Android phone +
Android TV, live TV first, with movies/series where authorised sources allow, and
must remain distributable without GPL source-disclosure obligations.

## 1. Hunter-Clipper/OpenIPTV — https://github.com/Hunter-Clipper/OpenIPTV

- **What it is:** Flutter/Dart IPTV player ("bring your own playlist", no content
  included). v0.14.33.
- **Licence:** **GPL-3.0** (verified from LICENSE file text and GitHub API).
- **Maintenance:** Very active — commits through 2026-10-27/28; created 2026-06-22;
  5 stars, 16 open issues (feature requests, image-loading performance).
- **Architecture highlights:**
  - Stack close to ours: flutter_riverpod + riverpod_annotation, go_router ^13,
    drift + sqlite3 (+ SQLCipher encrypted storage), xml for XMLTV,
    flutter_secure_storage, workmanager background refresh.
  - **Player: native Kotlin Media3/ExoPlayer platform view** (verified
    `NativeVideoPlayer.kt` using `ExoPlayer`, `HlsMediaSource`, `TsExtractor`,
    track selection). Strongest live-TV architecture on Android (hardware decode,
    HLS/TS-native).
  - M3U (URL + file), Xtream Codes, XMLTV EPG with full TV-guide view; 51 test
    files vs ~130 lib files.
  - Android TV verified: Leanback in manifest, TV remote focus rail.
- **Foundation viability:** Functionally closest match, but **GPL-3.0 blocks use
  as a code foundation for closed/commercial distribution**. Design reference
  only; copy zero lines.
- **Red flags:** GPL (decisive), very young project, single apparent maintainer,
  scope far beyond a v1.

## 2. clubanderson/clubTivi — https://github.com/clubanderson/clubTivi

- **What it is:** Flutter/Dart cross-platform IPTV player; headline feature
  "Smart Channels" (multi-source grouping with automatic failover on buffering).
- **Licence:** **Apache-2.0** (verified from LICENSE text) — commercially safe;
  attribution + NOTICE obligations only.
- **Maintenance — key nuance:** `pushed_at` 2026-10-25, but the **last real code
  commit to main is 2026-02-24** ("Android TV D-pad navigation"). Weekly
  "releases" through Oct 2026 are bot re-tags of the same main HEAD — automation,
  not development. Code dormant ~8 months. 107 stars; open issues on core flows
  ("Can't Add Provider", Fire OS install failure, update loops).
- **Architecture highlights:**
  - Stack is 1:1 with our scaffolded pubspec: flutter_riverpod, go_router ^14,
    **media_kit (+video/libs)**, dio, drift + sqlite3_flutter_libs, xml,
    freezed/json_serializable, mockito.
  - M3U + Xtream providers; **EPG is the standout**: 4-tier auto-mapping
    (explicit → tvgId → normalized name → call-sign), XMLTV from URL/file,
    timeline guide, lazy scoped EPG loading. Tests exist for m3u/xmltv/EPG
    mapping/failover (6 test files — thinner than OpenIPTV).
  - Android TV: Leanback launcher + `touchscreen required=false` manifest,
    `lib/platform/tv/tv_shell.dart`, D-pad work committed.
  - Player: media_kit (libmpv/FFmpeg) — broad codecs, but mpv-over-HLS on weak TV
    hardware is generally less proven than ExoPlayer for live TV (judgment, not
    repo-verified).
- **Foundation viability:** **The only repo whose licence permits using its code
  in a closed commercial Flutter app.** Viable donor for parser/EPG-mapper/
  failover internals.
- **Red flags:** dormancy, open onboarding bugs, thin tests, 0.4.0 pre-1.0.

## 3. moabualruz/crispy-tivi — https://github.com/moabualruz/crispy-tivi

- **What it is:** Flutter UI + **Rust core** (flutter_rust_bridge, rusqlite),
  IPTV + Jellyfin/Emby/Plex ambitions. v0.1.0-alpha.
- **Licence:** **CC BY-NC-SA 4.0** (verified from LICENSE.md; NOTICE.md frames it
  as study-only). Non-commercial + share-alike → **not usable at all** for a
  commercial app.
- **Maintenance:** Moderate (last main commits 2026-09-30, pushed 2026-10-28);
  29 stars, 0 open issues.
- **Architecture highlights:** media_kit player, riverpod 3 + go_router 17,
  M3U/Xtream/EPG/VOD/series, DVR, multiview, casting. Rust SQLite behind FFI.
- **Foundation viability:** Reference only (licence blocks use; Rust FFI fights a
  pure-Dart scaffold). Worth reading for TV UX ideas (multiview, guide zoom).
- **Red flags:** NC licence (decisive), alpha, over-ambitious scope.

## 4. iptv-org/iptv — https://github.com/iptv-org/iptv

- **What it is:** **Not an app** — a data catalog of publicly listed IPTV
  playlists (~142.6k stars, updated daily since 2018). EPG lives in the separate
  [iptv-org/epg](https://github.com/iptv-org/epg) repo (Unlicense).
- **Licence:** Unlicense (public-domain dedication) — covers the **catalog data
  and tooling, NOT the underlying streams**, whose rights the repo itself
  disclaims.
- **Relevance:** Dev/test fixtures and demo builds only.
- **Red flags:** as *shipped product content* it is the biggest legal risk on
  this list — many listed streams are arguably unlicensed retransmissions;
  bundling them invites takedowns and store rejection. Never ship without legal
  review; ADRIAN TV must remain a bring-your-own-source player.

## 5. Other scans

- [opentvproject/opentv](https://github.com/opentvproject/opentv) — Kotlin (not
  Flutter), GPL-3.0, TV-first, active. UX reference only.
- [DevelopersCoffee/airo](https://github.com/DevelopersCoffee/airo) — Flutter,
  MIT, active, includes an Android TV build; but a sprawling "super app" monorepo
  with 373 open issues. Mine TV bits under MIT only if needed; whole-repo
  adoption not advisable. Their write-up on fixing Flutter TV jank/OOM is worth
  reading before Phase 5.

## Scored recommendation (0–5)

| Repo | Flutter compat | Android + TV | Live-TV playback | EPG | Code quality | Licence (closed commercial) | Branding ease | Verdict |
|---|---|---|---|---|---|---|---|---|
| OpenIPTV | 5 | 5 | 4 (native Media3/ExoPlayer) | 5 | 4 | **1 (GPL-3.0)** | 2 | Design reference only |
| clubTivi | 5 (stack == ours) | 4 | 3 (media_kit; open core issues) | 5 | 3 | **5 (Apache-2.0)** | 4 | **Licensed code donor** |
| crispy-tivi | 4 (Rust FFI friction) | 4 | 4 (alpha) | 4 | 3 | **0 (CC BY-NC-SA)** | 1 | Reference only |
| iptv-org/iptv | 0 (data, not app) | 0 | 0 | 3 (via epg repo) | n/a | 5 data / **0 stream assurance** | n/a | Test data only, legal caveat |
| opentv (Kotlin) | 0 | 5 | 4 | ? | ? | 1 (GPL) | 1 | UX reference only |
| airo (Flutter) | 5 | 4 | n/v | n/v | 2 | 5 (MIT) | 3 | Selective mining only |

n/v = could not verify.

## Conclusion

**Build ADRIAN TV original; use OpenIPTV and crispy-tivi as read-only design
reference; designate clubTivi (Apache-2.0) as the sole licensed code donor** for
internals we do not want to hand-roll (M3U parser refinements, XMLTV/EPG
auto-mapping tiers, Smart-Channel failover engine) — each adoption reviewed for
attribution/NOTICE obligations. Our pubspec already mirrors that stack, so
divergence cost is low.

Escape hatch: if Android live-stream reliability demands it, replace media_kit
with a self-written Media3/ExoPlayer platform view (pattern studied from
OpenIPTV, implemented from scratch — no GPL code transfer).
