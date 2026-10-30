# Finger Ink — Viwoods notebook fork

Fork of [SMUsamaShah/fingerink.koplugin](https://github.com/SMUsamaShah/fingerink.koplugin), under the original AGPL-3.0 license.

Draw handwritten notes on KOReader pages with your finger. Designed for touch
e-readers without a stylus, including Kindle Paperwhite.

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

PDF export is one-way: after export, Finger Ink can no longer undo or erase
those strokes.

## Requirements

- KOReader 2026.03 or newer for drawing
- KOReader 2026.07 or newer for PDF export

## Install

### AppStore or Storefront

Finger Ink is structured for KOReader's AppStore and Storefront plugins. Find
**Finger Ink** in the store and install it, then restart KOReader. The store can
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

If Finger Ink is disabled in KOReader's plugin manager, enable it and restart
KOReader. Then open a document and use **Top menu → More tools → Finger Ink**.
The optional `Finger Ink: ...` actions exposed to KOReader's gesture manager
are shortcuts only; the plugin works without assigning any of them.

## Use

Open:

```text
Top menu → More tools → Finger Ink
```

A small status button always stays on the page, even if the old version's
**Hide** setting was saved. It writes out **READ / OFF**, **PEN / ON**,
**MARK / ON**, or **ERASE / ON**. Tap it to open the classic click-wheel panel.

The top header is the **active mode**. The black list row is the **browsed
choice**; browsing alone never changes tools. Rotate a finger around the ring,
or tap its left/right arrows, to move the highlighted row. Press the center
**SELECT** button to apply that choice:

- **Pen**, **Highlighter**, **Eraser** select the tool and enable drawing.
- **Read / select text** stops drawing for reading, text selection and dictionary lookup.
- **Undo stroke** removes the last stroke; **Pen width** cycles 2, 4 and 7 pixels.
- **Page note** opens the current page's typed note.
- **Close controls**, the ring's **MENU** button, or a tap outside closes the
  panel. The status button stays available to reopen it.
- The ring's bottom **READ / WRITE** button stops or resumes the last drawing tool.

Long-press and drag the collapsed status button to move it. Its position is saved.
The **Open tool wheel** menu item and gesture shortcut also open it. The panel
is rendered into a bounded cached buffer, with integer pixel positions and
measured text boxes at the current screen scale. Closing restores the page and
requests a clean refresh to remove stale panel outlines.

Drawing retains every distinct input point, merges overlapping brush stamps,
and batches Android display posts at 30 Hz by default. A pen lift flushes the
last pending pixels. **Display update rate** offers 20, 30 or 60 Hz; use 20 if
Android falls behind, and 60 only if the device can keep up. This reduces CPU and
window-copy overhead, but does not provide Viwoods' proprietary native pen latency.

On builds with KOReader's stylus callback API, pen events are captured separately,
including reported eraser and highlighter tools. Android must expose the pen type.

### Viwoods AiPaper Mini

1. Copy `fingerink.koplugin` into internal storage at `koreader/plugins/` using OpenMTP.
2. Restart KOReader and open a book, then **More tools → Finger Ink → Start drawing**.
3. Test the pen first. If it draws, enable **Stylus only (ignore fingers while drawing)**.
   This ignores every finger contact outside the toolbar while drawing, including
   multi-touch palms. Choose **Read** in the wheel to turn pages or select text; the status button remains usable.
4. Choose **Mark** in the wheel for a wide dotted freehand highlight that leaves
   printed text readable on a monochrome screen. PDF export uses translucent yellow ink.
5. For searchable text highlights, choose **Read** in the wheel or **Select text / highlight** in the
   menu, then long-press and select text using KOReader's normal highlight controls.
   Manage these in KOReader's Bookmarks; they are separate from freehand marks.

The connected device's diagnostic file reported KOReader
`v2026.07.2-206-g322551a_2026-09-28_android`. Its source includes the required stylus
callback API. File transfer was verified through OpenMTP; live pen accuracy, palm
behavior, PDF writes, and latency must still be checked on the tablet.

Other handwriting plugins can also register stylus callbacks or gesture hooks.
Disable **Stylus annotations** and **Ink Away** in KOReader's plugin manager and
restart before testing Finger Ink alone. Existing notes from those plugins are
not migrated or deleted. Finger Ink restores a previous stylus callback when drawing stops.

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

From the Finger Ink menu, choose:

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
- Exported PDF ink cannot be edited by Finger Ink.
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
