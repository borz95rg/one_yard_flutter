# Один двор — целая цивилизация: Flutter Android prototype

This is an incremental Flutter migration. It does not replace or modify
`one_yard_civilization_v19.html`.

## Implemented

### Stage 1 — viewport camera math

- Dependency-free 2D viewport camera math in `lib/game/viewport_camera.dart`.
- Drag/pan using screen-space deltas.
- Pinch zoom around the two-finger focal point, preserving the world point
  beneath the fingers.
- Configurable zoom limits and screen/world coordinate conversion.

### Stage 2 — versioned save format

- `GameSave` JSON envelope with explicit format, schema version, UTC timestamp
  and data-only payload.
- Rejects malformed roots and unsupported future schema versions.
- Legacy HTML localStorage saves are retained losslessly in `legacyHtmlSave`;
  only the verified world/time/season/ecology slice is mapped so far; all other fields remain pending.

### Stage 3 — app-private save storage and recovery

- `IoSaveFileStore` stores files in the app-private Application Support folder,
  not public Downloads/Music/media directories.
- `GameSaveRepository` writes a complete temporary file before replacing the
  primary save.
- The previous primary is retained as `.bak` after a successful new save.
- If the new temp file cannot be promoted, the previous primary is restored.
- If the primary JSON is corrupt/unsupported, loading falls back to the backup
  without deleting or overwriting the damaged primary.
- File I/O is behind `SaveFileStore`, allowing recovery logic to be tested with
  an in-memory fake.

### Stage 4 — typed world-state migration slice

- Added `WorldState` for the verified HTML save fields: season index/timer,
  world year, weather/timer, era index and ecology metrics.
- Legacy HTML saves now populate `payload.worldState` while the complete
  original object remains preserved under `legacyHtmlSave`.
- Missing/invalid values receive source-aligned defaults; season and era indices
  are bounded to the ranges observed in the HTML source.
- Added tests for mapping, invalid-value handling and JSON round-trip.
- This is data migration only: season progression, weather selection, harvests,
  disasters and ecology simulation are not ported yet.

### Stage 5 — season, weather and ecology simulation slice

- Added `NatureSimulation`, a data-only port of the source HTML
  `updateNatureSystems(dt)` rules. It advances seasons every 55 simulation
  seconds, updates weather every 18 seconds, and checks natural hazards every
  38 seconds.
- Preserves source formulas for summer/autumn harvest, winter food consumption,
  forest/wildlife recovery, settlement pollution pressure, rain/snow soil gain,
  drought damage, flood/storm/wildfire counters and food/morale effects.
- Randomness is injectable so behavior can be tested deterministically. The
  simulation returns updated state, food total, morale delta and event strings;
  the Flame/UI layer must apply those results to residents and display events.
- Weather particles and rendering are intentionally not part of this domain
  module. `natureEventTimer` is retained in the Flutter state; the HTML save
  does not persist that timer, so imported legacy saves start it at zero.
- Added deterministic tests for season transition/harvest, winter/year rollover,
  drought behavior and invalid delta time. Tests are authored but not executed
  here because Flutter/Dart SDK is unavailable.


### Stage 6 — isometric grid geometry

- Added dependency-free `IsometricGrid` geometry for a bounded tile map.
- Converts tile coordinates to isometric world-space centers and back.
- Resolves a world-space tap to a tile only when it falls inside that tile's diamond.
- Validates map and tile dimensions; includes round-trip and hit-test test cases.
- This is the mathematical foundation only: no Flame `GameWidget`, painter, sprites, gesture wiring or playable map has been added yet.

### Stage 7 — first Flame settlement scene

- Added a runnable Flutter Android app and Flame `GameWidget`.
- Draws an isometric settlement with terrain, roads, a river, trees, houses, a
  central fountain and resident figures.
- Added a responsive resource bar, settlement/ecology panels, and a bottom
  construction toolbar. Selecting a tool places another sample building.
- One-finger drag pans the camera; two-finger gestures pan and zoom.
- Added Android project scaffolding and a GitHub Actions workflow. Pushes to
  `main` or `master`, or a manual workflow run, build a release APK and store it
  as the `one-yard-android-apk` artifact.

This is the first playable rendering shell, not the complete HTML-game port:
toolbar construction currently adds visual sample buildings, and displayed
population/resource values are sample UI data. The nature and save modules are
not wired into this screen yet.

## UI direction confirmed

Use a modern isometric city-builder layout: isometric world view; compact top
bar for resources, population, time and era; contextual side panels; bottom
construction toolbar; separate research panel. Retain the mountain-settlement
identity and existing simulation systems from HTML/JS Canvas v19.

## Build and run

```bash
flutter pub get
flutter run
```

Build a local release APK with `flutter build apk --release`. GitHub Actions
performs the same release build and publishes the APK as a downloadable
workflow artifact after a push to the default branch.

## Important source audit

The supplied HTML source currently writes `version: 18` to `localStorage` under
`one_yard_save`, despite the supplied file being named v19. Its save includes
world/season/weather/nature/culture/nation/economy/research fields, objects,
residents, factions and family/social identifiers. Loading respawns residents
and maps saved resident IDs to newly generated runtime IDs by array index;
therefore it does not preserve residents' exact runtime positions/IDs.

The Flutter save layer must use explicit schema migrations and must not assume
the HTML save version matches its filename. The current importer only wraps
and preserves the legacy object; it does not yet map simulation fields into
Dart domain models.

## Next integration step

Connect the existing versioned save and nature simulation to the game screen,
then migrate resident and economy rules from the HTML source in small verified
slices. Preserve unported legacy save fields until their Dart models exist.

## Source status

The original HTML v19 source remains the behavioral reference. This folder
contains a runnable visual prototype and migration foundation, not a complete
feature-equivalent port.
