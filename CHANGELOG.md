## 0.5.0 — classic click wheel and clear Spanish speech

- Replace orbiting tool bubbles with a classic click-wheel panel: rotate/arrow to browse, center SELECT to commit.
- Separate the active tool header from the browsed choice; use explicit ON/OFF status in the persistent launcher.
- Render into a bounded cached buffer using integer coordinates, antialiased ring edges and measured text boxes.
- Restore old/new panel bounds and perform a clean refresh on close.
- Replace legacy Spanish clips with full-quality Piper neural voice data in a separate local pack.
- Add independent English/Spanish pronunciation toggles and Normal/Slower/Very slow Spanish playback speeds with pitch preservation.
- Validate bounds at multiple DPI scales and test persistence, visibility and native speed parameters.

## 0.4.0 — faster writing and permanent radial controls

- Replace the removable toolbar with a permanent state hub and tap-to-open radial wheel.
- Show the active tool, select pen/marker/eraser directly, and offer Read, Undo, Note and width controls.
- Merge brush runs and batch display posts at 30 Hz, with a final pen-up flush and cancellation on redraw.
- Add optional offline English and Spanish dictionary audio plugin and a local recording packer.
- Cover wheel input, hidden-control recovery, refresh coalescing, and audio lifecycle with tests.
- Device latency and physical speaker output need live verification.

## 0.3.0 — Viwoods notebook fork

- Capture native KOReader stylus callbacks, restore prior handlers, and use touch rotation.
- Optional stylus-only drawing blocks finger/palm drawing and page turns outside the toolbar.
- Cycle pen, readable dotted freehand marker, and eraser; export marker ink with PDF opacity.
- Browse annotated pages, navigate to them, and attach or edit typed page notes.
- Export an offline HTML notebook with embedded SVG handwriting and escaped typed notes.
- Fix erasing long segments with sparse samples; discard strokes crossing a page change.
- Track edits in document settings and point the updater to this fork.
- Device input behavior still requires live validation on Viwoods; existing plugin data stays separate.

# Changelog

## 0.2.1 - 2026-08-31

- Add reliable AppStore and Storefront update detection through matching
  plugin metadata and stable GitHub releases.
- Add CI-verified release packaging with an installable
  `fingerink.koplugin.zip` asset.
- Document that no KOReader gesture configuration is required.
- Keep documentation and development files outside the installable plugin
  directory and release archive.

## 0.2 - 2026-08-30

- Add a compact icon toolbar with a remembered movable position.
- Prevent the toolbar from swallowing input intended for KOReader.
- Export supported strokes as native PDF ink annotations.
