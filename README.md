# Один двор — целая цивилизация: Flutter migration foundation

This is the first isolated migration increment. It does not replace or modify
`one_yard_civilization_v19.html`.

## Implemented in this stage

- Dependency-free 2D viewport camera math in `lib/game/viewport_camera.dart`.
- Drag/pan using screen-space deltas.
- Pinch zoom around the two-finger focal point, preserving the world point
  beneath the fingers.
- Configurable zoom limits and screen/world coordinate conversion.
- Unit tests for inverse coordinate conversion, focal zoom, zoom clamping,
  and drag direction.

## UI direction confirmed

Use a modern isometric city-builder layout: isometric world view; compact top
bar for resources, population, time and era; contextual side panels; bottom
construction toolbar; separate research panel. Retain the mountain-settlement
identity and the existing simulation systems from HTML/JS Canvas v19.

## Run tests on a Flutter workstation

```bash
flutter pub get
flutter test
```

## Next integration step

Create the Flame `GameWidget` and adapt `ViewportCamera` to
`CameraComponent`/`CameraComponent.viewfinder`. Connect `ScaleStartDetails` and
`ScaleUpdateDetails` from Flutter's `GestureDetector` (or Flame pointer events)
to pan and focal zoom. Then migrate the HTML v19 state into typed Dart models;
do not rewrite resident/economy/social simulation until its data structures
and save format have been mapped.

## Source status

The original HTML v19 source is retained separately and is the behavioral
reference. This folder is a starter module, not yet a complete runnable game.

## Findings from the v19 HTML save/load audit

The source currently writes `version: 18` to `localStorage` under
`one_yard_save`, despite the supplied file being named v19. The save includes
world/season/weather/nature/culture/nation/economy/research fields, objects,
residents, factions and family/social identifiers. Loading respawns residents
and maps saved resident IDs to newly generated runtime IDs by array index;
therefore it does not preserve the residents' exact runtime positions/IDs.

The Flutter save layer must use an explicit schema version and migrations, and
must not assume that the HTML save's version number matches its filename. A
future importer should preserve the HTML save as a read-only legacy format and
map all supported fields deliberately.

## Stage 2 — versioned save container

Added `lib/persistence/game_save.dart` and `test/game_save_test.dart`.

- Flutter saves use an explicit `format`, `schemaVersion`, UTC timestamp and
  JSON `payload`.
- Decoder rejects malformed roots and unsupported future schema versions.
- Legacy HTML localStorage saves (including the observed `version: 18`) are
  wrapped without dropping any original fields. The original object is kept in
  `legacyHtmlSave`; field-by-field conversion is intentionally deferred until
  typed models are verified.
- This stage does not yet write to Android storage. The next integration is a
  repository using `path_provider` (or an equivalent app-private directory),
  atomic temp-file replacement, and a backup/restore test.

Tests added: Flutter save round-trip, full legacy-object preservation, and
malformed/unsupported input rejection. Run `flutter test` on a machine with the
Flutter SDK; this environment has no Flutter or Dart executable, so tests could
not be executed here.
