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
