# Changelog

## 0.4.0 — independent Dictionary Audio

- Publish Dictionary Audio in its own repository with a dedicated plugin ZIP, CI and release workflow.
- Add a built-in updater targeting this repository.
- Preserve English/Spanish switches, Spanish speed preferences, installed pack paths and dictionary popup buttons.
- Retain the optional PageScribe Audio shortcut through the existing `ui.dictionary_audio:showSettings()` integration.
- Keep pack generators and source attribution; dictionaries, recordings and models remain separate user data.

## Earlier releases

The plugin previously shipped as an optional package in [seshakiran/fingerink.koplugin](https://github.com/seshakiran/fingerink.koplugin). Its development history is preserved here. Version 0.3.1 added the audio settings dialog; earlier versions introduced offline English and neural Spanish playback, independent language switches and pitch-preserving Spanish speed settings.
