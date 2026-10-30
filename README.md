# Offline Dictionary Audio for KOReader

English pronunciation recordings and Spanish pronunciation for KOReader dictionary popups on Android. **Dictionary Audio installs and works independently of PageScribe.** When both plugins are installed, PageScribe provides a convenient Audio shortcut.

## Feature video

https://github.com/user-attachments/assets/561f65a5-9c4f-4087-a0ba-2a357c53295f

## Install the plugin

1. Download **dictionary-audio.koplugin.zip** from the [latest release](https://github.com/seshakiran/dictionary-audio.koplugin/releases/latest).
2. Extract it and copy **dictionary-audio.koplugin** into KOReader’s **plugins** directory.
3. Install the audio packs described below, then fully close and reopen KOReader.
4. Open a book, look up a word, and tap **Hear English** or **Hear Spanish**.

The final plugin path is `koreader/plugins/dictionary-audio.koplugin/main.lua`. If upgrading from the earlier bundled package, replace that same folder. Existing language preferences, speed settings, dictionaries and audio packs are compatible; no pack conversion or redownload is needed.

Requirements: Android and a KOReader build exposing `dictionary:addToDictButtons`. The Viwoods development build was v2026.07.2-206. Spanish speed control uses Android PlaybackParams (Android 6 or newer). On other platforms the code can load its menu, but Android MediaPlayer playback is unavailable.

## Use by itself

**Top menu → More tools → Dictionary audio** provides independent English and Spanish ON/OFF switches and Spanish speech speed:

- **Normal:** 100%
- **Slower:** 85%, the default
- **Very slow:** 70%

Playback speed preserves the voice’s pitch; English stays at normal speed. Settings persist across books and restarts. Disabling a language hides its dictionary button and stops its current clip. Use Android’s media volume for loudness. **Update plugin** in this menu follows this repository.

**Hear English** plays the English headword. **Hear Spanish** lists the looked-up English word’s translations; tap a Spanish word to hear its pronunciation. These buttons pronounce words, rather than reading definitions aloud.

## Use together with PageScribe

Install [PageScribe](https://github.com/seshakiran/pagescribe.koplugin) and Dictionary Audio as two separate plugins, then restart KOReader. PageScribe detects this plugin and shows **Audio** in its tray. That button opens these same pronunciation settings. Finger text selection and dictionary lookup remain KOReader’s native behavior.

Neither repository bundles or requires the other. Definition dictionaries and audio packs are separate data. For developers, the integration contract is `reader_ui.dictionary_audio:showSettings()`, registered when Dictionary Audio initializes.

## Audio packs and definition dictionaries

The release ZIP contains plugin code and its license. It does **not** contain voice models, pronunciation recordings or dictionary definitions. Keep your existing packs, or build packs using the tools below. Required playback files are:

```text
koreader/data/dict/english-audio/english.pack
koreader/data/dict/english-audio/english.tsv
koreader/data/dict/spanish-neural-audio/spanish.pack
koreader/data/dict/spanish-neural-audio/spanish.tsv
koreader/data/dict/spanish-neural-audio/spanish-translations.tsv
```

Only install the languages you want. Each `.tsv` index maps a word to the byte offset and length of its clip inside the matching `.pack`; index and pack files must come from the same build. Missing recordings are reported without falling back to an online service.

KOReader supplies the dictionary lookup interface. Install definition dictionaries separately—for example, [GCIDE from KOReader’s catalog](https://github.com/koreader/koreader/blob/master/frontend/ui/data/dictionaries.lua) for English definitions and [WikDict English–Spanish](https://download.wikdict.com/dictionaries/stardict/wikdict-en-es.zip) for translations. The plugin does not replace KOReader’s dictionary engine. Preserve the dictionaries’ source and license files.

### English recordings

Obtain the [WyabdcRealPeopleTTS archive](https://sourceforge.net/projects/stardict-4/files/WyabdcRealPeopleTTS/) from its upstream source, then run:

```sh
python3 scripts/pack-english-audio.py WyabdcRealPeopleTTS.tar.bz2 english-audio
```

The script packs existing human recordings without altering their audio bytes and skips invalid WAV files. Coverage is smaller than a full definition dictionary. Recordings are upstream data, not part of this code repository.

### Spanish neural pronunciation

The current Spanish voice is synthetic Mexican Spanish, **Piper es_MX-claude-high**, stored as lossless FLAC at 22,050 Hz / 16-bit. It is locally generated audio, not a human recording.

The included legacy generator extracts translation metadata from an uncompressed WikDict StarDict `.idx` / `.dict` pair and builds an eSpeak seed pack:

```sh
python3 scripts/pack-spanish-audio.py wikdict-en-es.idx wikdict-en-es.dict spanish-seed
```

That step requires the eSpeak NG shared library. The old seed audio is not used for playback by this version. To replace it with the clearer neural voice, obtain the model and its matching JSON configuration from the [Piper voice repository](https://huggingface.co/rhasspy/piper-voices/tree/main/es/es_MX/claude/high), then run in a Python environment with `piper-tts`, `numpy`, `onnxruntime` and `soundfile`:

```sh
python3 scripts/pack-spanish-neural.py spanish-seed es_MX-claude-high.onnx spanish-neural-audio
```

`SPANISH_PACE` defaults to `1.12`; `SPANISH_WORKERS` and `SPANISH_THREADS` control generation parallelism. Matching partial builds can resume; model/term/pace manifests prevent mixing different builds. Copy the completed neural directory to the playback path above, keeping `SOURCE.txt` and `generation.json`. The runtime speed preference is independent of generation pace.

Model, voice dataset, recordings and dictionary data have their own upstream licenses. The Spanish generator records the voice/model-card and WikDict attribution in `SOURCE.txt`. See the [model card](https://huggingface.co/rhasspy/piper-voices/blob/main/es/es_MX/claude/high/MODEL_CARD) and [Piper project](https://github.com/OHF-Voice/piper1-gpl) for upstream details.

## Development and releases

Run `lua5.1 dictionary-audio-test.lua` for word normalization, bounded MediaPlayer playback, cleanup, translation choices, independent settings, speed persistence and the optional PageScribe settings dialog. Run `./scripts/package.sh` to build `dist/dictionary-audio.koplugin.zip`. CI validates Lua 5.1 behavior, Python syntax and package contents before automatic releases. Tests simulate JNI; actual sound quality and device playback require hardware checks.

The updater replaces only the plugin folder. Audio packs and dictionary definitions stay under KOReader’s data directory.

## License and origin

AGPL-3.0, as distributed in the earlier repository; see [LICENSE](LICENSE). This repository preserves that development history. The shared updater originated in the PageScribe/Finger Ink development work. The preserved history also records the original Finger Ink source attribution; this plugin does not depend on its handwriting code.
