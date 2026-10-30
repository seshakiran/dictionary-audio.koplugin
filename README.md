# PageScribe — pen and touch notes for KOReader

Fork of [SMUsamaShah/fingerink.koplugin](https://github.com/SMUsamaShah/fingerink.koplugin), under the original AGPL-3.0 license.

Write and highlight directly on KOReader book pages with a pen or finger.
Includes native Android stylus capture for Viwoods, palm blocking, page notes,
and notebook export. Finger drawing also supports touch devices such as Kindle Paperwhite.

https://github.com/user-attachments/assets/c9c4f543-999a-47e8-8ae3-d14274997e5f

<details>
<summary>(FFMPEG commands that compressed this video 35MB -> 3MB)</summary>

```
ffmpeg -y -i input.mp4 -c:v libx264 -b:v 600k -pass 1 -an -f null NUL
ffmpeg -i input.mp4 -c:v libx264 -b:v 600k -pass 2 -c:a aac -b:a 128k output.mp4
```
</details>

Your ink is saved per page in KOReader's sidecar data, where it can be undone
or erased. For PDFs, you can optionally export the ink as native PDF
annotations so it is visible in Acrobat, Preview, and other PDF readers.

PDF export is one-way: after export, PageScribe can no longer undo or erase
those strokes.

## Requirements

- KOReader 2026.03 or newer for drawing
- KOReader 2026.07 or newer for PDF export

## Install

### AppStore or Storefront

PageScribe keeps the original `fingerink` identity for compatible store updates.
A store may still list it as **Finger Ink** until its catalog is updated. The store can
compare the stable GitHub release with the version in `_meta.lua` and offer
future updates.

### Manual installation

Download `fingerink.koplugin.zip` from the
[latest release](https://github.com/seshakiran/fingerink.koplugin/releases/latest),
extract it, and copy the resulting `fingerink.koplugin` directory into
KOReader's `plugins` directory:

```sh
scp -r fingerink.koplugin root@<kindle>:/mnt/us/koreader/plugins/
```

The final path should be:

```text
koreader/plugins/fingerink.koplugin/main.lua
```

Restart KOReader after installing.

## KOReader setup

No gesture setup is required. You do not need to assign or disable KOReader's
long-press gesture.

If PageScribe is disabled in KOReader's plugin manager, enable it and restart
KOReader. Then open a document and use **Top menu → More tools → PageScribe**.
The optional `PageScribe: ...` actions exposed to KOReader's gesture manager
are shortcuts only; the plugin works without assigning any of them.

## Use

Open:

```text
Top menu → More tools → PageScribe
```

The tray collapses to a small **handwriting icon**, just 48 × 30
logical pixels. Tap it to open a larger inline tool strip. The launch tab stays small, while
the opened tray uses the screen’s normal scale and larger touch targets. The default position is midway down the right
edge, away from KOReader’s progress bar. Saved custom positions are preserved;
the previous bottom-edge default is moved to the middle on upgrade.

Tap **Read | Pen | Highlight | Erase** to activate a tool immediately. A filled
button and checkmark show the active tool. Its options appear **inline below the
strip**, so the page stays visible:

- **Pen:** 2 / 4 / 7 / 9 / 10 / 12 px widths.
- **Highlight:** 12 / 24 / 36 px widths, independent of the pen.
- **Pen only / Pen + finger:** switch input directly in the same strip.
- **Read:** stops handwriting and removes the options row for reading and word lookup.
- **Undo:** removes the last page stroke; unavailable when there is no page ink.
- **Notes:** opens typed page notes, noted-page navigation and HTML export.
- **Audio:** directly opens independent English and Spanish switches and Spanish speed.
- **‹:** collapses the tray, preserving the active tool.

**Drag anywhere on the tab or expanded tray** to move it. No long press is
required. It follows the drag, stays within the screen and saves its final
position. Long-press dragging also works.

Dictionary audio also has its own **Top menu → More tools → Dictionary audio**
entry, separate from PageScribe.

The **Open toolbar** menu item and gesture shortcut also open the strip. The
tray uses a bounded cached buffer, integer pixel positions and measured text
boxes. Moving it reuses its cached pixels and restores the page beneath it.

Drawing retains every distinct input point, merges overlapping brush stamps,
and batches Android display posts at 30 Hz by default. A pen lift flushes the
last pending pixels. **Display update rate** offers 20, 30 or 60 Hz; use 20 if
Android falls behind, and 60 only if the device can keep up. This reduces CPU and
window-copy overhead, but does not provide Viwoods' proprietary native pen latency.

On builds with KOReader's stylus callback API, pen events are captured separately,
including reported eraser and highlighter tools. Android must expose the pen type.

### Viwoods AiPaper Mini

1. Copy `fingerink.koplugin` into internal storage at `koreader/plugins/` using OpenMTP.
2. Restart KOReader and open a book, then **More tools → PageScribe → Start drawing**.
3. Test the pen first. If it draws, enable **Stylus only (ignore fingers while drawing)**.
   This ignores every finger contact outside the toolbar while drawing, including
   multi-touch palms. Choose **Read** in the toolbar to turn pages or select text; the status button remains usable.
4. Choose **Highlight** in the toolbar for a wide dotted freehand highlight that leaves
   printed text readable on a monochrome screen. PDF export uses translucent yellow ink.
5. For searchable text highlights, choose **Read** in the toolbar or **Select text / highlight** in the
   menu, then long-press and select text using KOReader's normal highlight controls.
   Manage these in KOReader's Bookmarks; they are separate from freehand marks.

The connected device's diagnostic file reported KOReader
`v2026.07.2-206-g322551a_2026-09-28_android`. Its source includes the required stylus
callback API. File transfer was verified through OpenMTP; live pen accuracy, palm
behavior, PDF writes, and latency must still be checked on the tablet.

Other handwriting plugins can also register stylus callbacks or gesture hooks.
Disable **Stylus annotations** and **Ink Away** in KOReader's plugin manager and
restart before testing PageScribe alone. Existing notes from those plugins are
not migrated or deleted. PageScribe restores a previous stylus callback when drawing stops.

### Manage written notes

- **Book notebook** lists every page with handwriting or a typed note, sorted by page.
  Open an entry to jump there, edit the note, or delete its ink and typed note after confirmation.
- **Add or edit this page note** opens a full-screen text editor. The first line labels
  that page in the notebook. Emptying and saving the text removes the typed note.
- **Export notebook (HTML with handwriting)** creates `your-book.ext.fingerink.html`
  beside the book. Open it in a browser to read, search typed notes, or print it.
  The file embeds SVG handwriting and typed notes, with no network dependencies.
  It does not include the copyrighted book pages, OCR, other plugins' ink, or native
  KOReader text highlights. Older strokes lacking canvas dimensions use a 1000×1400 fallback.
- Sidecar data holds editable strokes and typed notes. Back up the book's KOReader
  sidecar too. HTML export is a viewing copy, not an importable backup.
  Ink exported into the PDF leaves the sidecar and is no longer listed as editable ink.
- Clearing ink through the original clear commands preserves typed notes. The notebook's
  **Delete page ink and note** command removes both.

## Export ink into a PDF

From the PageScribe menu, choose:

- **Save this page into PDF**
- **Save whole document into PDF**

For reliable export, use page view. Continuous PDF view is supported when
each stroke stays within one page. Strokes crossing the gap between pages are
not exported.

Ink drawn while reflow or page rotation is enabled may not be exportable.
Those strokes remain in the sidecar and the plugin explains what to correct.

## Limitations

- Stylus-only mode blocks fingers while drawing when pen identification is available.
  Finger mode has no palm rejection.
- Changing layout after writing can move text while leaving ink behind,
  especially in reflowable books such as EPUBs.
- Exported PDF ink cannot be edited by PageScribe.
- Fast refresh may look grainy or leave temporary ghosting.

## Documentation

- `spec.md` — implementation details
- `decisions.md` — design decisions
- `requirements.md` — original requirements

## Releases

The repository includes CI and release workflows; fork owners may need to enable
GitHub Actions. Version changes merged to `main` are tested and packaged as
a release when those workflows are enabled. The release ZIP contains only the installable
`fingerink.koplugin` directory; repository documentation and development files
remain outside it.

## Offline dictionaries and pronunciation on Android

The optional `dictionary-audio.koplugin.zip` release asset adds **Hear English**
and **Hear Spanish** to dictionary popups using KOReader's dictionary-button
extension API, present in the inspected Viwoods build. Both play fully local
clips through Android MediaPlayer, with no online calls or API keys.

- English uses the original human-recorded WyabdcRealPeopleTTS audio. Its
  coverage is smaller than the English definition dictionary.
- Spanish uses **Piper es_MX-claude-high**, a neural Mexican Spanish voice.
  The clips retain the model's 22,050 Hz, 16-bit output with lossless FLAC
  compression. They are synthetic pronunciations, not human recordings.
  This replaces the earlier low-quality eSpeak 8-bit/11 kHz pack.
- **Hear Spanish** opens a scrollable list of the English word's translations.
  Tap a Spanish term to hear it. Neither audio button reads whole definitions.

### Audio preferences

Open **Top menu → Tools → More tools → Dictionary audio**:

- **English pronunciation** independently shows/hides English audio.
- **Spanish pronunciation** independently shows/hides Spanish audio. Turning it
  off keeps English audio and Spanish dictionary text available.
- **Spanish speech speed** offers **Normal**, **Slower (85%)**, and **Very slow
  (70%)**. Slower is the default. Playback speed changes preserve pitch and apply
  on the next Spanish clip; English remains at its normal speed.

Settings persist across books and restarts. They do not require regenerating
or reinstalling audio packs. Disabling a language stops its current clip.
Speed control requires Android's PlaybackParams API (Android 6+), supported by
the inspected Viwoods build. Physical playback and rendering still need tablet
validation after each update; desktop tests do not reproduce the e-ink controller.

### Dictionary data and reproducible audio

Install the audio plugin in `koreader/plugins/` and restart KOReader. Put
GCIDE and WikDict English–Spanish in separate folders under `koreader/data/dict/`.
Preserve their attribution and licenses. GCIDE has 108,121 entries (GPLv3+), from
KOReader's [official download catalog](https://github.com/koreader/koreader/blob/master/frontend/ui/data/dictionaries.lua).
[WikDict English–Spanish](https://www.wikdict.com/page/download) has 67,225 entries
(CC BY-SA 4.0).

The audio packs are user data and are not bundled in plugin releases:

```text
koreader/data/dict/english-audio/english.pack
koreader/data/dict/english-audio/english.tsv
koreader/data/dict/spanish-neural-audio/spanish.pack
koreader/data/dict/spanish-neural-audio/spanish.tsv
koreader/data/dict/spanish-neural-audio/spanish-translations.tsv
```

Prepare the English recordings from the
[WyabdcRealPeopleTTS download](https://stardict-4.sourceforge.net/index_en.php.html):

```sh
python3 scripts/pack-english-audio.py WyabdcRealPeopleTTS.tar.bz2 english-audio
```

The old `scripts/pack-spanish-audio.py` creates the legacy eSpeak pack and its
translation metadata. To replace those clips with the neural model, use an
isolated Python environment with `piper-tts` and `soundfile` installed:

```sh
python scripts/pack-spanish-neural.py spanish-audio es_MX-claude-high.onnx spanish-neural-audio
```

Download the model and its JSON configuration from
[the Piper voice repository](https://huggingface.co/rhasspy/piper-voices/tree/main/es/es_MX/claude/high).
The model card identifies the voice dataset license as Apache-2.0; Piper is
GPL-3.0. Generation runs locally, preserves the original translation keys, and
can resume a matching partial pack. Voice/pace manifests prevent mixing builds.
Use Android's media volume for playback volume.

### PageScribe 0.9 controls

The small draggable tray keeps tool options inline. Active state is visible;
there are no pending choices or tool-setting dialogs. Native pens can draw, highlight, erase, and tap
the toolbar. Pen-only mode blocks finger ink and page gestures while keeping
controls accessible. Pen compatibility depends on KOReader exposing the
device's native stylus events.

Color screens automatically use a blue, amber, coral, and teal palette with
RGB-preserving text and shapes. Monochrome screens keep explicit labels and
high-contrast rendering. No state depends on color alone.

The product name is PageScribe. The `fingerink.koplugin` install folder, update
URL, internal settings, and gesture identifiers remain stable to preserve
existing notes and upgrades. Do not install a second copy under a new folder.

Quick drags and long-press drags both release the tray correctly. Its button
targets follow the rendered tray at the current screen position. A new tap
recovers from an interrupted drag instead of leaving the controls locked.
