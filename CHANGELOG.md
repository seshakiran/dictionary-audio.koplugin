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
