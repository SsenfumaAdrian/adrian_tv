# ADRIAN TV

A premium, original Flutter streaming application for Android phones and
Android TV (adaptable to other Flutter platforms). **Live television is a
first-class feature**; movies and series appear when your configured sources
provide them.

> ADRIAN TV is a **media player and content-discovery application**. It does
> not host, bundle, sell or provide any TV channels, movies or series, and it
> does not guarantee access to any content. You can only watch sources you
> are authorised to use.

## Features

- Cinematic dark home screen with featured hero, content rails, continue
  watching and favourites.
- Live TV: channel grid/list, category chips, in-list filter, favourites.
- Player (media_kit / libmpv+FFmpeg): HLS & TS playback, auto-hiding controls,
  stream error overlay with retry, wake-lock, "up next" guide panel.
- EPG: XMLTV support per source, now/next with live progress bar, guide
  screen, 1-minute refresh.
- Multiple user-configured M3U/M3U8 sources (remote URL), enable/disable,
  disk-cached parsing with TTL, resilient per-source failure handling.
- Search across all enabled sources; watch history.
- Android TV: Leanback launcher intent, touchscreen-optional manifest,
  side-rail navigation at ≥ 900 dp, focus-glow theme helpers.
- Bundled **demo source** of clearly-labelled public test streams so the app
  is explorable on first run without any provider.

## Getting started

```bash
flutter pub get
flutter run                  # phone/emulator
flutter test                 # unit + widget tests
flutter analyze              # static checks
```

Android builds require the Android SDK (`flutter doctor` will tell you).
Release signing is not yet configured — see docs/IMPLEMENTATION_PLAN.md.

## Adding a content source

Settings → Content sources → **Add M3U playlist source**:

- Name: anything you like.
- Playlist URL: an `http(s)` URL serving an M3U/M3U8 extended playlist.
- EPG URL (optional): an XMLTV guide for that playlist.

Only add playlists you own or are authorised to access. Playlist bodies are
cached under the app support directory; provider credentials are never
required by the current source types and must never be committed to Git.

## Privacy & security

- No analytics or tracking of any kind.
- Sources, favourites and history are stored on-device only
  (`shared_preferences`); the design reserves `flutter_secure_storage` for
  any future credential-bearing provider types (e.g. Xtream Codes).
- The app only contacts the playlist/EPG/stream URLs you configure.

## Project structure

```
lib/
  app/          # MaterialApp + go_router
  core/         # theme, brand widgets
  data/         # models, M3U/XMLTV parsers, repositories, services, prefs
  features/     # splash, shell, home, channels, player, epg, search,
                # settings, providers (Riverpod)
```

Design decisions and phase status: [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md).
Upstream research and licence analysis: [docs/REPOSITORY_EVALUATION.md](docs/REPOSITORY_EVALUATION.md).

## Licensing notes

- ADRIAN TV branding assets in `assets/` are original.
- Typography uses Inter via `google_fonts` (SIL OFL) at runtime.
- `clubTivi` (Apache-2.0) is the designated code-donor for any future
  adoption of its parser/failover internals; attribution will be recorded
  in `NOTICE` if code is imported. GPL-licensed repositories studied during
  research were used as read-only references — no code was copied.
