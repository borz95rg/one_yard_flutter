# Один двор — целая цивилизация: Flutter migration foundation

This is an incremental migration foundation. It does not replace or modify
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
- Randomness is injectable. The game scene applies returned food and morale
  changes and forwards natural-event messages to the event feed.
- Weather particles and rendering are intentionally not part of this domain
  module. `natureEventTimer` is retained in the Flutter state; the HTML save
  does not persist that timer, so imported legacy saves start it at zero.
- Existing tests cover season transition/harvest, winter/year rollover, drought
  behavior and invalid delta time. Tests were not run in this continuation.


### Stage 6 — isometric grid geometry

- Added dependency-free `IsometricGrid` geometry for a bounded tile map.
- Converts tile coordinates to isometric world-space centers and back.
- Resolves a world-space tap to a tile only when it falls inside that tile's diamond.
- Validates map and tile dimensions; includes round-trip and hit-test test cases.
- This geometry is used by the Flame scene for map taps and building placement.

### Stage 7 — Android scene and reference layout

- Added a Flutter Android app using Flame's `GameWidget`, a generated
  isometric village, touch panning and pinch zoom.
- Arranged resource/time headers, category navigation, population/economy/
  ecology panels, district legend and minimap, events, technology, and an
  eight-option construction toolbar to follow the supplied UI composition.
- Building placement uses isometric tile hit-testing and construction material
  costs. The map is still vector artwork, not the detailed city art in the
  supplied image; several panels remain works in progress.
- Added GitHub Actions to produce a release APK artifact on branch pushes or
  manual runs.

### Stage 8 — residents, nature and starter economy

- Residents have individual needs, personality, age and morale; they wander,
  choose useful sites, walk to them, and satisfy needs.
- Added nearby friendships/rivalries, marriages, child births, basic inherited
  traits and family/generation counts.
- The economy assigns starter jobs and updates food, construction materials,
  goods, trade, tax and treasury on timed market steps. Construction debits
  materials.
- Season, weather and ecology simulation runs in the game scene, affecting food
  and morale and feeding natural-event messages into the UI.
- Residents, market values and map buildings are connected to the scene UI.
- Game state loads from and autosaves to app-private storage; the top-bar save
  control writes immediately. The repository keeps and can recover from a backup.
- The importer retains the complete legacy HTML save and maps available resident
  and market data. The HTML source does not save resident positions or needs, so
  those use initialized values after import.
- Factions, healthcare, traffic, diplomacy, education/research, multi-city
  world systems and historical progression still need migration. Several
  dashboard values and research/category controls remain illustrative.

## UI direction

Use a modern isometric city-builder layout: isometric world view; compact top
bar for resources, population, time and era; contextual side panels; bottom
construction toolbar; separate research panel. Retain the mountain-settlement
identity and existing simulation systems from HTML/JS Canvas v19.

## Run tests on a Flutter workstation

```bash
flutter pub get
flutter test
```

Tests are present for camera math, save-envelope round-trip/legacy preservation,
storage recovery, grid geometry, world-state migration and ecology simulation.
They have not been run in this continuation.

## Important source audit

The supplied HTML source currently writes `version: 18` to `localStorage` under
`one_yard_save`, despite the supplied file being named v19. Its save includes
world/season/weather/nature/culture/nation/economy/research fields, objects,
residents, factions and family/social identifiers. Loading respawns residents
and maps saved resident IDs to newly generated runtime IDs by array index;
therefore it does not preserve residents' exact runtime positions/IDs.

The Flutter save layer must use explicit schema migrations and must not assume
the HTML save version matches its filename. The current importer preserves the
legacy object and maps only verified world and ecology fields. Resident and
economy simulation imports are still pending.

## Next integration steps

Continue the migration with households, public health, research, factions,
statehood, culture, traffic, trade networks and historical eras; expose each
system through working controls and preserve its persisted data. Replace the
procedural vector map with detailed artwork and connect remaining dashboard
values and research/category controls to game state.

## Source status

The original HTML source remains the behavioral reference. This is a runnable
Android prototype with several migrated systems, not yet feature-equivalent.
The local machine has no Android SDK, so the GitHub Actions workflow is the
intended APK build path after the project is pushed.
