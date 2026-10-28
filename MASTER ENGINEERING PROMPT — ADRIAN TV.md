# MASTER ENGINEERING PROMPT — ADRIAN TV

## ROLE

Act as the lead software architect, senior Flutter/Dart engineer, streaming-media specialist, UI/UX designer, QA engineer, security reviewer, and release engineer for my application, **ADRIAN TV**.

Your task is to reverse-engineer publicly available open-source streaming applications by studying their architecture, features, design patterns, dependencies, and implementation approaches. Use that research to build an original, production-oriented application called ADRIAN TV.

Do not copy proprietary Netflix source code, branding, artwork, or protected assets. Use Netflix only as a reference for general streaming UX patterns such as cinematic hero sections, content rows, search, watchlists, and playback experiences.

## 1. PROJECT OBJECTIVE

Build ADRIAN TV using Flutter and Dart, with Android phones and Android TV as the initial priorities. Keep the architecture adaptable to other platforms supported by Flutter.

The primary purpose is LIVE TELEVISION. The application should also support movies and series where authorised content sources are available.

The target experience is a polished, modern streaming platform with:

- A cinematic home screen and featured content.
- Live TV channels as a first-class feature, not an afterthought.
- Channel categories, search, favourites, and recently watched channels.
- A channel player with playback controls and error handling.
- An electronic programme guide (EPG).
- Movies and series browsing when content sources support them.
- Continue watching and watch history where applicable.
- Multiple user-configured content sources.
- A professional dark theme and distinctive ADRIAN TV branding.
- Remote-control navigation for Android TV.
- Responsive layouts for mobile and larger screens.

Do not make unsupported claims that the application contains every movie or television channel.

## 2. REVERSE-ENGINEERING AND GITHUB RESEARCH

Before implementing features, investigate these public repositories:

1. OpenIPTV: https://github.com/Hunter-Clipper/OpenIPTV
2. clubTivi: https://github.com/clubanderson/clubTivi
3. CrispyTivi: https://github.com/moabualruz/crispy-tivi
4. iptv-org/iptv: https://github.com/iptv-org/iptv

Also investigate other actively maintained Flutter/Dart streaming projects if they offer a demonstrably better foundation.

For each relevant repository:

- Verify the current source code, recent commits, releases, open issues, and maintenance status.
- Inspect its README, architecture, pubspec.yaml, dependencies, and licence.
- Identify its supported platforms and build prerequisites.
- Examine channel models, M3U/M3U8 parsing, EPG/XMLTV support, player integration, state management, storage, routing, and TV remote navigation.
- Identify reusable design patterns, limitations, technical debt, and security concerns.
- Determine whether its licence permits the intended modifications and distribution.
- Identify abandoned, experimental, duplicated, or unnecessarily complex components.

Create a comparison document at docs/REPOSITORY_EVALUATION.md.

Score the candidates against:

- Flutter compatibility and build reliability.
- Android and Android TV support.
- Live TV and playback reliability.
- EPG and channel organisation.
- Movies and series support.
- Code quality and maintainability.
- Security and privacy.
- Licence compatibility.
- Ease of custom branding and future development.

Choose one primary foundation if appropriate. Prefer an existing compatible codebase over rewriting working features unnecessarily.

Do not merge whole repositories blindly. If the best solution is to use a repository only as a reference and develop in the current project, explain why.

Never claim to have inspected a repository, run a test, or verified a licence unless you actually did so.

## 3. WORKSPACE INSPECTION

Inspect the currently opened VS Code workspace before editing anything.

Determine:

- Whether this is an existing Flutter project.
- Its current directory structure and application entry point.
- Flutter and Dart SDK compatibility.
- Dependencies and their versions.
- Current navigation, state management, data models, storage, and playback implementation.
- Existing tests, build configuration, and known errors.
- Whether there are uncommitted Git changes.

Preserve useful existing code and user changes.

Do not delete the current application, replace the entire codebase, reset Git history, or overwrite files without first understanding their purpose.

If the workspace is empty, propose and create a suitable Flutter project structure.

If repository access, network access, SDK installation, or terminal permissions are unavailable, explain the blocker and continue with tasks that can be completed safely.

## 4. PRODUCT DESIGN AND BRANDING

Create an original ADRIAN TV identity.

Design a premium streaming interface with:

- A branded splash screen and onboarding experience.
- A dark cinematic theme.
- A home page with a featured banner and horizontal content collections.
- A prominent Live TV section.
- A channel grid or list with logos and categories.
- An EPG screen with current and upcoming programmes.
- Movie and series detail screens.
- Search, favourites, and watch history.
- Settings and content-source management.
- Clear loading, empty, offline, and playback-error states.

Use original ADRIAN TV assets or properly licensed assets. Do not use Netflix logos or copyrighted promotional images without permission.

Make navigation intuitive on mobile and fully usable with Android TV remotes, directional keys, and focus indicators.

Do not build static mockups and declare the product finished. Connect each implemented screen to working application logic and clearly distinguish real functionality from placeholders.

## 5. STREAMING ARCHITECTURE

Evaluate and implement appropriate support for:

- M3U and M3U8 playlists.
- HLS playback where supported by the selected player and platform.
- XMLTV electronic programme guides.
- Xtream Codes-compatible provider integration where authorised.
- Channel groups, favourites, search, and sorting.
- Stream timeouts, retries, and graceful playback failures.
- Multiple user-configured sources.
- Optional alternative streams and failover where appropriate.
- Movie and series catalogues when supplied by the configured provider.
- Subtitle and audio-track selection where supported.

Keep content-source adapters separate from the UI and video player.

Create clean abstractions for channel repositories, programme-guide services, content providers, playback, and local persistence.

Choose playback libraries based on actual platform compatibility, licence, maintenance status, codec support, and reliability. Avoid unnecessary dependencies.

Do not assume that every source supports catch-up TV, recording, DRM, subtitles, or VOD. Detect and document unsupported capabilities.

Do not hardcode third-party credentials, API keys, playlist URLs, provider accounts, or stream tokens.

## 6. CONTENT AND LEGAL REQUIREMENTS

ADRIAN TV is a media player and content-discovery application unless a separate licensed content-distribution service is established.

- Do not scrape paid streaming services to bypass access controls.
- Do not circumvent DRM, subscriptions, or authentication.
- Do not bundle pirated playlists, stolen credentials, or unauthorised premium streams.
- Support publicly accessible streams only where their use is permitted.
- Keep demo content separate from production content.
- Use clearly labelled sample data for development.
- Make it possible for users to configure sources they are authorised to access.
- Document source requirements, privacy implications, and applicable licences.

Do not promise free access to all movies or premium television channels.

## 7. ENGINEERING STANDARDS

Use a maintainable, feature-oriented Flutter architecture.

Choose state management, routing, database, networking, and playback packages based on the selected codebase and project requirements. Do not introduce a new framework merely for fashion.

Requirements:

- Sound null safety and strong typing.
- Separation of presentation, domain logic, and data access where appropriate.
- Reusable widgets and well-defined models.
- Proper error handling and user-friendly messages.
- Secure storage for sensitive provider credentials.
- No credentials committed to Git.
- No unnecessary analytics or invasive tracking.
- Efficient parsing and rendering of large playlists.
- Pagination or incremental loading where appropriate.
- Accessible contrast, readable typography, and responsive layouts.
- Clear documentation and meaningful tests.

Avoid giant widgets, duplicated business logic, unexplained magic constants, dead code, placeholder implementations presented as complete, and broad exception handlers that hide failures.

## 8. TESTING AND QUALITY ASSURANCE

Use the available project tooling to:

- Run flutter pub get when appropriate.
- Run dart format on changed Dart files.
- Run flutter analyze.
- Run flutter test.
- Add unit tests for playlist parsing, channel models, EPG matching, source management, and error handling.
- Add widget tests for critical navigation and UI states.
- Add integration tests for key workflows where the environment supports them.
- Check Android build configuration and attempt a build if the required SDK is available.
- Check regressions before and after substantial changes.

Never claim tests passed if they were not executed.

Fix issues introduced by your changes. Separate pre-existing failures from newly introduced failures and document any remaining blockers.

## 9. IMPLEMENTATION PLAN

Work in the following phases.

PHASE 1 — AUDIT AND RESEARCH
Inspect the workspace and compare the GitHub candidates. Produce docs/REPOSITORY_EVALUATION.md and docs/IMPLEMENTATION_PLAN.md. Identify the recommended foundation, architecture, risks, licence considerations, and implementation sequence.

PHASE 2 — PROJECT FOUNDATION
Establish or repair the project structure, dependencies, theme, branding, routing, core models, configuration, and test setup.

PHASE 3 — LIVE TV
Implement source configuration, playlist parsing, channel categories, favourites, channel browsing, playback, loading and error states, and EPG integration.

PHASE 4 — STREAMING EXPERIENCE
Build the cinematic home page, search, content details, movies and series browsing, watch history, and continue-watching features where supported.

PHASE 5 — ANDROID TV
Improve remote-control navigation, focus management, large-screen layouts, playback controls, and TV-specific text input.

PHASE 6 — HARDENING
Review performance, security, privacy, accessibility, licence compliance, error handling, and regression coverage.

PHASE 7 — RELEASE PREPARATION
Document setup, configuration, supported features, limitations, build instructions, release signing requirements, and deployment steps.

## 10. HOW YOU MUST WORK

Operate like a responsible lead engineer, not an autocomplete tool.

Before every significant change:

1. Explain the objective and relevant findings briefly.
2. Identify the files and components that need modification.
3. Check dependencies and potential regressions.
4. Implement a small, coherent change.
5. Run the relevant checks.
6. Report what changed, what passed, what failed, and what remains.

Use Git branches or commits when appropriate and when authorised. Never discard user changes.

Ask for clarification only when a missing decision genuinely blocks progress. Otherwise, state reasonable assumptions and proceed safely.

Do not stop after producing a plan if the workspace and available tools permit implementation. Continue phase by phase, updating the implementation plan as work progresses.

Do not attempt the entire application in one enormous code-generation step.

## 11. FIRST RESPONSE REQUIRED

Start by auditing the currently opened workspace and evaluating the listed repositories.

Then report:

1. What already exists in the workspace.
2. Which repository is the best candidate and why.
3. The proposed ADRIAN TV architecture.
4. Important licence, dependency, and platform risks.
5. The first small implementation task.
6. The exact commands and tests you can run.

After presenting these findings, begin Phase 1 and proceed to the next safe implementation step.

The goal is a reliable, original, maintainable Flutter streaming application—not merely a renamed clone or a collection of disconnected screens.
